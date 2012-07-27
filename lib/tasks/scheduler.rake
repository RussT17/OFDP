namespace :futures do
  namespace :scrape do
    
    desc "scrape american sources (CME,ICE,ICU)"
    task :set1, [:days_ago] => :environment do |t,args|
      args.with_defaults(:days_ago => '0')
      input_date = Date.today - args.days_ago.to_i
      if input_date.wday == 0 || input_date.wday == 6
        puts "# input date is a weekend; doing nothing"
        exit
      end
      scraper = FutureScraper.new
      scraper.add_source(:cme,input_date)
      scraper.add_source(:icu,input_date)
      scraper.add_source(:ice,input_date)
      scraper.full_run
    end
    
    desc "scrape eurex"
    task :eur => :environment do
      
    end
    
  end
  
  desc "purge invalid futures contracts based on invalid months table"
  task :validate => :environment do
    Future.all.each do |future|
      bad_months = future.asset.invalid_contract_months.map{|row| row.month}
      if bad_months.include? future.month
        puts future.asset.symbol + future.month + future.year.to_s
        future.destroy
      end
    end
  end
  
  desc "delete cfc entries with no associated rows"
  task :empty_cfcs => :environment do
    Cfc.all.each do |cfc|
      cfc.destroy if cfc.future_data_rows.empty?
      puts cfc.asset + cfc.depth.to_s
    end
  end
  
  namespace :update_cfcs do
    desc "create associations between the future data rows and the cfc table"
    task :cfc, [:asset] => :environment do |t,args|
      #update a specific asset, or if none specified updates all with names.
      args.with_defaults(:asset => nil)
      Asset.all.each do |asset|
        next if asset.name.nil?
        next if !args.asset.nil? and args.asset != asset.symbol
        asset.future_data_rows.order("date desc").uniq.pluck(:date).each do |date|
          the_rows = asset.future_data_rows.where(:date => date).sort {|row1,row2| row1.future.date_obj <=> row2.future.date_obj}
          bump_count = 0
          the_rows.each_with_index do |the_row,i|
            depth = i + 1
            if !the_row.cfc_id.nil?
              next_row = the_row.cfc.future_data_rows.where("date > ?", date).order("date asc").first
            end
            if !next_row.nil?
              if next_row.future.date_obj < the_row.future.date_obj
                bump_count = bump_count + 1
              end
            end
            depth = depth + bump_count
            target_cfc = Cfc.where(:asset_id => the_row.asset.id,:depth => depth).first
            if target_cfc
              the_row.cfc = target_cfc
              the_row.save
            else
              the_row.create_cfc(:asset_id => the_row.asset.id,:depth => depth)
            end
            puts "Asset: " + the_row.asset.id.to_s + " Date: " + the_row.date.to_s + " Depth: " + (depth).to_s
            t2 = Time.now
          end
        end     
      end
    end
  end 
end


namespace :options do
  namespace :scrape do
    desc "Scrape Yahoo Finance for options data for all ticker symbols in the table"
    task :yahoo => :environment do
      if (Date.today - 1).wday == 0 || (Date.today - 1).wday == 6
        puts "# input date is a weekend; doing nothing"
        exit
      end
      require 'net/http'
      require 'uri'
      require 'json'
      Stock.all.each do |stock|
        puts "Looking for #{stock.symbol} options"
        url = 'http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.options%20where%20symbol%20in%20(%22' + \
          stock.symbol + '%22)&format=json&diagnostics=true&env=http%3A%2F%2Fdatatables.org%2Falltables.env&callback='
        uri = URI.parse(url)
        #send query to YQL a second time if the first attempt fails
        options = nil
        1.upto(2) do
          begin
            response = Net::HTTP.get_response(uri)
            options = JSON.parse(response.body)["query"]["results"]["optionsChain"]["option"]
            options = [options] if options.is_a?(Hash)
            break
          rescue
          end
        end
        #if there are no options report it and continue
        if !options.nil?
          options.each do |option|
            #find the expiry date from yahoo's code. Note some weird cases: "DUK1120721C00017000" (extra 1 after ticker symbol)
            x = stock.symbol.length
            y = nil
            option["symbol"][x..-1].split(//).each_with_index do |char,i|
              if char == 'C' or char == 'P'
                y = i - 1
              end
            end
            expiry_date = Date.strptime(option["symbol"][(y-5+x)..(y+x)],'%y%m%d')
            is_call = (option["type"] == 'C')
            option_record = stock.stock_options.where(:symbol => option["symbol"]).first_or_create(:expiry_date => expiry_date, :is_call => is_call, :strike_price => option["strikePrice"])
            option_record.stock_option_data_rows.where(:date => (Date.today - 1)).first_or_create.update_attributes(:last_trade_price => option["lastPrice"], :change => option["change"], :bid => option["bid"], :ask => option["ask"], :volume => option["vol"], :open_interest => option["openInt"])
          end
          puts "Found #{options.length.to_s}"
        else
          puts "None found"
        end
      end
    end
  end
end

namespace :metals do
  namespace :scrape do
    require "nokogiri"
    require "open-uri"
    require "date"
    namespace :history do
      
      desc "Scrape all precious metal price history"
      task :precious => :environment do
    
        puts "this task will start by deleting all existing precious metal data."
        puts "continue? (enter to continue, ctrl-c to cancel)"
        STDIN.gets
        
        PreciousFixing.delete_all
        PreciousForward.delete_all
       
        #Gold stuff
        metal_id = Metal.where(:name=>'Gold').first.id

        #Gold Fixings
        1968.upto(Date.today.year) do |year|
          url = "http://www.lbma.org.uk/pages/index.cfm?page_id=53&title=gold_fixings&show=" + year.to_s + "&type=daily"
          doc = Nokogiri::HTML(open(url))
          table = doc.css('table.pricing_detail')
          table.css('caption').remove
          header = table.css('thead:nth-child(1)').remove
          numcols = header.css('tr:nth-child(2) th').to_a.length
          table.css('tr').to_a.each do |row|
            row_data = Array.new
            row.css('*:not(a)').each_with_index do |cell,i|
              row_data[i] = cell.content
            end
            next if row_data[0] == ""
            #since website uses two digit years which confuse ruby, let's sub in our
            #four digit years instead
            row_data[0] = row_data[0][0,row_data[0].length-2] + year.to_s
            #turn blank entries and words like "day off for christmas" into nil cells
            row_data.each_index do |j|
              next if j == 0
              temp = /[0-9.]+/.match(row_data[j]).to_s
              row_data[j] = temp != "" ? temp.to_f : nil
            end
            if numcols == 5
              puts MetalDataset.where(:metal_id => metal_id, :name => 'London Fixings A.M.').first.create_data_row(:date => Date.parse(row_data[0]), :usd => row_data[1], :gbp => row_data[2]) if !row_data[1,2].compact.empty?
              puts MetalDataset.where(:metal_id => metal_id, :name => 'London Fixings P.M.').first.create_data_row(:date => Date.parse(row_data[0]), :usd => row_data[3], :gbp => row_data[4]) if !row_data[3,4].compact.empty?
            end
            if numcols == 7
              puts MetalDataset.where(:metal_id => metal_id, :name => 'London Fixings A.M.').first.create_data_row(:date => Date.parse(row_data[0]), :usd => row_data[1], :gbp => row_data[2], :eur => row_data[3]) if !row_data[1,3].compact.empty?
              puts MetalDataset.where(:metal_id => metal_id, :name => 'London Fixings P.M.').first.create_data_row(:date => Date.parse(row_data[0]), :usd => row_data[4], :gbp => row_data[5], :eur => row_data[6]) if !row_data[4,6].compact.empty?
            end
          end
        end
          
        #Gold Forwards
        1989.upto(Date.today.year) do |year|
          url = "http://www.lbma.org.uk/pages/index.cfm?page_id=55&title=gold_forwards&show=" + year.to_s
          doc = Nokogiri::HTML(open(url))
          table = doc.css('table.pricing_detail_small')
          table.css('thead').remove
          table.css('tr').to_a.each do |row|
            row_data = Array.new
            row.css('td').each_with_index do |cell,i|
              row_data[i] = cell.content
            end
            next if row_data[0] == ""
            #since website uses two digit years which confuse ruby, let's sub in our
            #four digit years instead
            row_data[0] = row_data[0][0,row_data[0].length-2] + year.to_s
            #turn blank entries and words like "day off for christmas" into nil cells
            row_data.each_index do |j|
              next if j == 0
              temp = /[\-0-9.]+/.match(row_data[j]).to_s
              row_data[j] = temp != "" ? temp.to_f : nil
            end
            if year == 1989
              puts MetalDataset.where(:metal_id => metal_id, :name => 'Forward Offered Rates').first.create_data_row(:date => Date.parse(row_data[0]), 
                :gofo1 => row_data[1], :gofo3 => row_data[2], :gofo6 => row_data[3], :gofo12 => row_data[4], :libor1 => row_data[9],
                :libor3 => row_data[10], :libor6 => row_data[11], :libor12 => row_data[12]) if !row_data[1,4].compact.empty? or !row_data[9,12].compact.empty?
            else
              puts MetalDataset.where(:metal_id => metal_id, :name => 'Forward Offered Rates').first.create_data_row(:date => Date.parse(row_data[0]), 
                :gofo1 => row_data[1], :gofo2 => row_data[2], :gofo3 => row_data[3], :gofo6 => row_data[4], :gofo12 => row_data[5], :libor1 => row_data[11],
                :libor2 => row_data[12], :libor3 => row_data[13], :libor6 => row_data[14], :libor12 => row_data[15]) if !row_data[1,5].compact.empty? or !row_data[11,15].compact.empty?
            end
          end
        end

        #Silver Stuff
        metal_id = Metal.where(:name=>'Silver').first.id

        #Silver Fixings
        1968.upto(Date.today.year) do |year|
          url = "http://www.lbma.org.uk/pages/index.cfm?page_id=54&title=silver_fixings&show=" + year.to_s + "&type=daily"
          doc = Nokogiri::HTML(open(url))
          table = doc.css('table.pricing_detail')
          table.css('caption').remove
          header = table.css('thead:nth-child(1)').remove
          numcols = header.css('tr:nth-child(2) th').to_a.length
          table.css('tr').to_a.each do |row|
            row_data = Array.new
            row.css('*:not(a)').each_with_index do |cell,i|
              row_data[i] = cell.content
            end
            next if row_data[0] == ""
            #since website uses two digit years which confuse ruby, let's sub in our
            #four digit years instead
            row_data[0] = row_data[0][0,row_data[0].length-2] + year.to_s
            #turn blank entries and words like "day off for christmas" into nil cells
            row_data.each_index do |j|
              next if j == 0
              temp = /[0-9.]+/.match(row_data[j]).to_s
              row_data[j] = temp != "" ? temp.to_f : nil
            end
            1.upto(3) {|i| row_data[i] = row_data[i]/100 if !row_data[i].nil?}
            if numcols == 3
              puts MetalDataset.where(:metal_id => metal_id, :name => 'London Fixings').first.create_data_row(:date => Date.parse(row_data[0]), :usd => row_data[1], :gbp => row_data[2]) if !row_data[1,2].compact.empty?
            end
            if numcols == 4
              puts MetalDataset.where(:metal_id => metal_id, :name => 'London Fixings').first.create_data_row(:date => Date.parse(row_data[0]), :usd => row_data[1], :gbp => row_data[2], :eur => row_data[3]) if !row_data[1,3].compact.empty?
            end
          end
        end

        #Silver forwards
        2006.upto(Date.today.year) do |year|
          url = "http://www.lbma.org.uk/pages/index.cfm?page_id=56&title=silver_forwards&show=" + year.to_s
          doc = Nokogiri::HTML(open(url))
          table = doc.css('table.pricing_detail')
          table.css('thead').remove
          table.css('tr').to_a.each do |row|
            row_data = Array.new
            row.css('td').each_with_index do |cell,i|
              row_data[i] = cell.content
            end
            next if row_data[0] == ""
            #since website uses two digit years which confuse ruby, let's sub in our
            #four digit years instead
            row_data[0] = row_data[0][0,row_data[0].length-2] + year.to_s
            #turn blank entries and words like "day off for christmas" into nil cells
            row_data.each_index do |j|
              next if j == 0
              temp = /[\-0-9.]+/.match(row_data[j]).to_s
              row_data[j] = temp != "" ? temp.to_f : nil
            end
            puts MetalDataset.where(:metal_id => metal_id, :name => 'Indicative Forward Mid Rates').first.create_data_row(:date => Date.parse(row_data[0]), 
              :gofo1 => row_data[1], :gofo2 => row_data[2], :gofo3 => row_data[3], :gofo6 => row_data[4], :gofo12 => row_data[5], :libor1 => row_data[6],
              :libor2 => row_data[7], :libor3 => row_data[8], :libor6 => row_data[9], :libor12 => row_data[10]) if !row_data[1,10].compact.empty?
          end
        end
        
      end
      
      desc "Scrape history of data on non-precious metals"
      task :nonprecious => :environment do
        require 'spreadsheet'
        require 'nokogiri'
        require 'net/http'
        require 'open-uri'
        require 'date'
        
        doc = Nokogiri::HTML(open("http://www.lme.com/dataprices_historical.asp"))
        links = doc.css('a.greenSmallBold')
        links.to_a.each do |link|
          if /Price/.match(link['onclick'])
            path = link['href']
            puts path
            url = "http://www.lme.com" + link['href']
            book = nil
            open(url) do |f|
              book = Spreadsheet.open f
            end
            Metal.where("source = 'lme'").each do |metal|
              puts metal.name
              sheet_name = case metal.name
              when "NASAAC"
                "NA Alloy"
              when "Aluminium"
                "Primary Aluminium"
              when "Steel Billet"
                "Global Steel"
              else
                metal.name
              end
              sheet = book.worksheet sheet_name
              sheet.each 8 do |row|
                if row[1].class.name == 'Date'
                  date = row[1]
                  metal.metal_datasets.each_with_index do |dataset,i|
                    buyer = row[3*i + 2]
                    seller = row[3*i + 3]
                    puts dataset.name
                    puts dataset.first_or_create_data_row(:date => date).update_attributes(:buyer => buyer, :seller => seller)
                  end
                end
              end
            end
          end
        end 
      end
    end
    
    namespace :single do
      
      desc "Scrape one days prices from the lbma"
      task :precious, [:days_ago] => :environment do |t,args|
        args.with_defaults(:days_ago => '0')
        
        date = Date.today - args.days_ago.to_i
        
        #delete this year's worth of forward data, we're just going to overwrite it anyway
        PreciousForward.where("date >= ?",Date.parse('January-01-date.year.to_s')).delete_all
        
        #Gold Fixings
        metal_id = Metal.where(:name=>'Gold').first.id
        url = "http://www.lbma.org.uk/pages/index.cfm?page_id=53&title=gold_fixings&show=" + date.year.to_s + "&type=daily"
        doc = Nokogiri::HTML(open(url))
        table = doc.css('table.pricing_detail')
        table.css('tr').to_a.each do |row|
          row_data = Array.new
          row.css('*:not(a)').each_with_index do |cell,i|
            row_data[i] = cell.content
          end
          next if row_data[0] == ""
          #since website uses two digit years which confuse ruby, let's sub in our
          #four digit years instead
          row_data[0] = row_data[0][0,row_data[0].length-2] + date.year.to_s
          #check if this is the correct date!
          begin
            next if Date.parse(row_data[0]) != date
          rescue
            next
          end
          #turn blank entries and words like "day off for christmas" into nil cells
          row_data.each_index do |j|
            next if j == 0
            temp = /[0-9.]+/.match(row_data[j]).to_s
            row_data[j] = temp != "" ? temp.to_f : nil
          end
          if !row_data[1,3].compact.empty?
            MetalDataset.where(:metal_id => metal_id, :name => 'London Fixings A.M.').first.first_or_create_data_row(:date => Date.parse(row_data[0])).update_attributes(:usd => row_data[1], :gbp => row_data[2], :eur => row_data[3])
            puts "Gold Fixing A.M. updated"
          end
          if !row_data[4,6].compact.empty?
            MetalDataset.where(:metal_id => metal_id, :name => 'London Fixings P.M.').first.first_or_create_data_row(:date => Date.parse(row_data[0])).update_attributes(:usd => row_data[4], :gbp => row_data[5], :eur => row_data[6])
            puts "Gold Fixing P.M. updated"
          end
        end  
        
        #Gold Forward (just gets the whole year since libor rates have a delay)
        url = "http://www.lbma.org.uk/pages/index.cfm?page_id=55&title=gold_forwards&show=" + date.year.to_s
        doc = Nokogiri::HTML(open(url))
        table = doc.css('table.pricing_detail_small')
        table.css('thead').remove
        table.css('tr').to_a.each do |row|
          row_data = Array.new
          row.css('td').each_with_index do |cell,i|
            row_data[i] = cell.content
          end
          next if row_data[0] == ""
          #since website uses two digit years which confuse ruby, let's sub in our
          #four digit years instead
          row_data[0] = row_data[0][0,row_data[0].length-2] + date.year.to_s
          #turn blank entries and words like "day off for christmas" into nil cells
          row_data.each_index do |j|
            next if j == 0
            temp = /[\-0-9.]+/.match(row_data[j]).to_s
            row_data[j] = temp != "" ? temp.to_f : nil
          end
          MetalDataset.where(:metal_id => metal_id, :name => 'Forward Offered Rates').first.create_data_row(:date => Date.parse(row_data[0]), 
            :gofo1 => row_data[1], :gofo2 => row_data[2], :gofo3 => row_data[3], :gofo6 => row_data[4], :gofo12 => row_data[5], :libor1 => row_data[11],
            :libor2 => row_data[12], :libor3 => row_data[13], :libor6 => row_data[14], :libor12 => row_data[15]) if !row_data[1,5].compact.empty? and !row_data[11,15].compact.empty?
        end
        puts "Gold Forward Updated"
        
        #Silver Fixings
        metal_id = Metal.where(:name=>'Silver').first.id
        url = "http://www.lbma.org.uk/pages/index.cfm?page_id=54&title=silver_fixings&show=" + date.year.to_s + "&type=daily"
        doc = Nokogiri::HTML(open(url))
        table = doc.css('table.pricing_detail')
        table.css('tr').to_a.each do |row|
          row_data = Array.new
          row.css('*:not(a)').each_with_index do |cell,i|
            row_data[i] = cell.content
          end
          next if row_data[0] == ""
          #since website uses two digit years which confuse ruby, let's sub in our
          #four digit years instead
          row_data[0] = row_data[0][0,row_data[0].length-2] + date.year.to_s
          #check if this is the correct date!
          begin
            next if Date.parse(row_data[0]) != date
          rescue
            next
          end
          #turn blank entries and words like "day off for christmas" into nil cells
          row_data.each_index do |j|
            next if j == 0
            temp = /[0-9.]+/.match(row_data[j]).to_s
            row_data[j] = temp != "" ? temp.to_f : nil
          end
          1.upto(3) {|i| row_data[i] = row_data[i]/100 if !row_data[i].nil?}
          if !row_data[1,3].compact.empty?
            MetalDataset.where(:metal_id => metal_id, :name => 'London Fixings').first.first_or_create_data_row(:date => Date.parse(row_data[0])).update_attributes(:usd => row_data[1], :gbp => row_data[2], :eur => row_data[3])
            puts "Silver fixing updated"
          end
        end
        
        #Silver forwards (again, just gets the whole year)
        url = "http://www.lbma.org.uk/pages/index.cfm?page_id=56&title=silver_forwards&show=" + date.year.to_s
        doc = Nokogiri::HTML(open(url))
        table = doc.css('table.pricing_detail')
        table.css('thead').remove
        table.css('tr').to_a.each do |row|
          row_data = Array.new
          row.css('td').each_with_index do |cell,i|
            row_data[i] = cell.content
          end
          next if row_data[0] == ""
          #since website uses two digit years which confuse ruby, let's sub in our
          #four digit years instead
          row_data[0] = row_data[0][0,row_data[0].length-2] + date.year.to_s
          #turn blank entries and words like "day off for christmas" into nil cells
          row_data.each_index do |j|
            next if j == 0
            temp = /[\-0-9.]+/.match(row_data[j]).to_s
            row_data[j] = temp != "" ? temp.to_f : nil
          end
          MetalDataset.where(:metal_id => metal_id, :name => 'Indicative Forward Mid Rates').first.create_data_row(:date => Date.parse(row_data[0]), 
            :gofo1 => row_data[1], :gofo2 => row_data[2], :gofo3 => row_data[3], :gofo6 => row_data[4], :gofo12 => row_data[5], :libor1 => row_data[6],
            :libor2 => row_data[7], :libor3 => row_data[8], :libor6 => row_data[9], :libor12 => row_data[10]) if !row_data[1,10].compact.empty?
        end
        puts "Silver Forwards Updated"
        
      end
      
      desc "Scrape the LME for yesterday's non-precious metal closing prices"
      task :nonprecious => :environment do
        Metal.where(:source => "lme").all.each do |metal|
          puts metal.name.downcase
          url = "http://www.lme.com" + metal.data_path
          doc = Nokogiri::HTML(open(url))
          begin
            date = Date.parse(/for/.match(doc.css("b.primaryHeader").first.content.gsub(/\s/,"")).post_match)
          rescue
            next
          end
          table = doc.css("table table table").first
          if ["aluminium","copper","zinc","lead","nickel","aluminium alloy","nasaac"].include? metal.name.downcase
            row_data = Array.new
            table.css("td").to_a.each_with_index do |cell,i|
              temp = /[\-0-9.\,]+/.match(cell.content.gsub(/,/,"")).to_s.strip
              row_data[i] = temp != "" ? temp.to_f : nil
            end
            puts metal.metal_datasets.where(:name => "Cash").first.first_or_create_data_row(:date => date).update_attributes(:buyer => row_data[6], :seller => row_data[7]) if !row_data[6].nil? and !row_data[7].nil?
            puts metal.metal_datasets.where(:name => "3-Months").first.first_or_create_data_row(:date => date).update_attributes(:buyer => row_data[10], :seller => row_data[11]) if !row_data[10].nil? and !row_data[11].nil?
            puts metal.metal_datasets.where(:name => "December 1").first.first_or_create_data_row(:date => date).update_attributes(:buyer => row_data[14], :seller => row_data[15]) if !row_data[14].nil? and !row_data[15].nil?
            puts metal.metal_datasets.where(:name => "December 2").first.first_or_create_data_row(:date => date).update_attributes(:buyer => row_data[18], :seller => row_data[19]) if !row_data[18].nil? and !row_data[19].nil?
            puts metal.metal_datasets.where(:name => "December 3").first.first_or_create_data_row(:date => date).update_attributes(:buyer => row_data[22], :seller => row_data[23]) if !row_data[22].nil? and !row_data[23].nil?
          else
            row_data = Array.new
            table.css("td").to_a.each_with_index do |cell,i|
              temp = /[\-0-9.\,]+/.match(cell.content.gsub(/,/,"")).to_s.strip
              row_data[i] = temp != "" ? temp.to_f : nil
            end
            puts metal.metal_datasets.where(:name => "Cash").first.first_or_create_data_row(:date => date).update_attributes(:buyer => row_data[14], :seller => row_data[20]) if !row_data[14].nil? and !row_data[20].nil?
            puts metal.metal_datasets.where(:name => "3-Months").first.first_or_create_data_row(:date => date).update_attributes(:buyer => row_data[26], :seller => row_data[32]) if !row_data[26].nil? and !row_data[32].nil?
            puts metal.metal_datasets.where(:name => "15-Months").first.first_or_create_data_row(:date => date).update_attributes(:buyer => row_data[38], :seller => row_data[44]) if !row_data[38].nil? and !row_data[44].nil?
          end
        end
      end
      
    end 
  end
end