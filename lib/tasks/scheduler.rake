namespace :futures do
  namespace :scrape do
    require 'rubygems'
    require 'nokogiri'
    require 'open-uri'
    require 'date'
           
    fields = ['ticker','month','year','exchange']
  
    desc "scrape all sources (CME,ICE,ICU)"
    task :all, [:days_ago] => :environment do |t,args|
      def add_to_database(ex,cd,yr,mn,dt,record)
        the_asset = Asset.where(:exchange => ex, :symbol => cd).first_or_create
        the_future = the_asset.futures.where(:year => yr.to_i, :month => mn).first_or_create
        the_future.future_data_rows.where(:date => dt).first_or_create().update_attributes(record)
      end

      args.with_defaults(:days_ago => '0')
      input_date = Date.today - args.days_ago.to_i

      if input_date.wday == 0 || input_date.wday == 6
        puts "# input date is a weekend; doing nothing"
        exit
      end

      #First scrape CME

      fmon = { 'JAN' => 'F', 'FEB' => 'G', 'MAR' => 'H', 'APR' => 'J', 'MAY' => 'K', 'JUN' => 'M',
               'JLY' => 'N', 'AUG' => 'Q', 'SEP' => 'U', 'OCT' => 'V', 'NOV' => 'X', 'DEC' => 'Z' }

      dt = input_date
      du = sprintf("%02d/%02d/%04d", input_date.month, input_date.day, input_date.year)

      ur = 'http://www.cmegroup.com/CmeWS/mvc/xsltTransformer.do?xlstDoc=/XSLT/da/DailySettlement.xsl&url=/da/DailySettlement/V1/DSReport/ProductCode/%s/FOI/FUT/EXCHANGE/%s/Underlying/%s'
      ur = ur + '?tradeDate=' + du

      fnames = Hash.new     # exch.code => urlcode,outcode,exch,category,name
      File.open(Dir[Rails.root.join "lib/tasks/cmecodes"][0], "r") do |fp|
        while (s = fp.gets)
          next if s[0].chr == '#'
          a = s.split(',')
          break if a[0] == "\n"
          fnames[a[2]+'.'+a[0]] = [a[0].strip, a[1].strip, a[2].strip, a[3].strip, a[4].strip.chomp]
        end
      fp.close
      end
      fnames.each do |fn|
        record = Hash.new
        url = sprintf(ur, fn[1][0], fn[1][2], fn[1][0])
        #print fn[1][0] + ' '
        doc = Nokogiri::HTML(open(url))
        doc.css('table').each do |table|
          f=0
          table.css('tr').each do |tr|
            # skip headers
            if f>1
              s = "#{tr.css('td/text()')[0].to_s.strip}"
              break if !fmon.has_key?(s[0,3])
              mn = fmon[s[0,3]].to_s
              yr = '20' + s[4,2]
              cd = fn[1][1]
              ex = fn[1][2][1,4]
              printf "%s,%s,%s,%s,%s,", ex, cd, mn, yr, dt.to_s

              [1,2,3,6,7,8].each do |n|
                s = "#{tr.css('td/text()')[n].to_s.strip}"
                s.gsub!(/[A-Z]|,/,'')
                x=s
                if  (i=(s =~/'/))
                  if cd=='W' or cd=='YW'
                    #convert 1/8's to decimal
                    x = sprintf("%f", (s[0,i].to_f  + s[i+1..10].to_f/8))
                    x.sub!(/(?:(\..*[^0])0+|\.0+)$/, '\1')
                  else
                    #convert 1/32's to decimal
                    y =  s[0,i].to_f
                    c = s[i+1,3]
                    if s[i+3] and (s[i+3].chr =='2' or s[i+3].chr=='7')
                      c = c + '5'
                    else c = c + '0'
                    end
                    x = sprintf("%.5f", y + c.to_f/3200)
                  end
                end
                #adjust decimal places
                case cd
                  when 'JY'
                    #x = (x.to_f / 10000).to_s
                  when 'BR'
                    #x = (x.to_f * 1000).to_s
                  when 'QU'
                    #x = (x.to_f * 100).to_s
                end
                case n
                when 1
                  record[:open] = x.to_f
                when 2
                  record[:high] = x.to_f
                when 3
                  record[:low] = x.to_f
                when 6
                  record[:settle] = x.to_f
                when 7
                  record[:volume] = x.to_f
                when 8
                  record[:interest] = x.to_f
                end
                printf "%s", x
                print "," if n != 8
              end
              print "\n"
              add_to_database(ex,cd,yr,mn,dt,record)
              $stdout.flush
            end
            f+=1
          end  #rows
        end  #table
      end  #fnames

      #ICE

      fmon = { 'JAN' => 'F', 'FEB' => 'G', 'MAR' => 'H', 'APR' => 'J', 'MAY' => 'K', 'JUN' => 'M',
               'JUL' => 'N', 'AUG' => 'Q', 'SEP' => 'U', 'OCT' => 'V', 'NOV' => 'X', 'DEC' => 'Z' }

      dt = input_date

      ur = 'https://www.theice.com/marketdata/reports/icefutureseurope/EndOfDay.shtml?tradeDay=%d&tradeMonth=%d&tradeYear=%d&contractKey=%s'

      fnames = Hash.new     # exch.code => code,exch,category,name
      File.open(Dir[Rails.root.join "lib/tasks/icecodes"][0], "r") do |fp|
        while (s = fp.gets)
          next if s[0].chr=='#'
          a = s.split(',')
          break if a[0] == "\n"
          fnames[a[2].strip+'.'+a[1]] = [a[0].strip, a[1].strip, a[2].strip, a[3].strip, a[4].strip.chomp]
        end
      fp.close
      end

      fnames.each do |fn|
        record = Hash.new
        url = sprintf(ur, input_date.day, input_date.month-1, input_date.year, fn[1][0])
        url.gsub!(/\^/,'%5E')
        doc = Nokogiri::HTML(open(url))
        doc.css('table').each do |table|
          f=0
          table.css('tr').each do |tr|
            # skip headers
            if f>0
              s = "#{tr.css('td/text()')[0].to_s.strip.upcase}"
              break if !fmon.has_key?(s[0,3])
              next if "#{tr.css('td/text()')[1].to_s.strip}" =~ /Expired Contract/
              mn = fmon[s[0,3]].to_s
              yr = '20' + (s[3].chr == '-' ? s[4,2] : s[3,2]);
              cd = fn[1][1]
              ex = fn[1][2]
              ex = ex[1,3]
              printf "%s,%s,%s,%s,%s,", ex, cd, mn, yr, dt

              [1,2,3,4,7,11].each do |n|
                s = "#{tr.css('td/text()')[n].to_s.strip}"
                s.gsub!(/[A-Z]|,/,'')
                x=s
                case n
                when 1
                  record[:open] = x.to_f
                when 2
                  record[:high] = x.to_f
                when 3
                  record[:low] = x.to_f
                when 4
                  record[:settle] = x.to_f
                when 7
                  record[:volume] = x.to_f
                when 11
                  record[:interest] = x.to_f
                end
                printf "%s", x
                print "," if n != 11
              end
              add_to_database(ex,cd,yr,mn,dt,record)
              print "\n"
              $stdout.flush
            end
            f+=1
          end  #rows
        end  #table
      end  #fnames
      
      #ICU

      dt = input_date

      ur = 'https://www.theice.com/marketdata/nybotreports/getFuturesDMRResults.do?commodityChoice=%s&tradeDay=%d&tradeMonth=%d&tradeYear=%d&venueChoice=Electronic'

      fmon = { 'JAN' => 'F', 'FEB' => 'G', 'MAR' => 'H', 'APR' => 'J', 'MAY' => 'K', 'JUN' => 'M',
               'JUL' => 'N', 'AUG' => 'Q', 'SEP' => 'U', 'OCT' => 'V', 'NOV' => 'X', 'DEC' => 'Z' }

      fnames = Hash.new     # exch.code => code,exch,category,name
      File.open(Dir[Rails.root.join "lib/tasks/icucodes"][0], "r") do |fp|
        while (s = fp.gets)
          next if s[0].chr=='#'
          a = s.split(',')
          break if a[0] == "\n"
          fnames[a[1]+'.'+a[0]] = [a[0].strip, a[1].strip, a[2].strip, a[3].strip.chomp]
        end
      fp.close
      end

      fnames.each do |fn|
        record = Hash.new
        url = sprintf(ur, fn[1][0], input_date.day, input_date.month-1, input_date.year)
        url.gsub!(/\^/,'%5E')
        doc = Nokogiri::HTML(open(url))
        doc.css('table').each do |table|
          f=0
          table.css('tr').each do |tr|
            if false
              # this section for later
              #print "#{tr.css('th/text()')[0]},"
              [2,3,4,6,9,10].each do |n|
                #print "#{tr.css('th/text()')[n].to_s.strip}"
                #print "," if n!=8
              end
              #print "\n"
            end
            # skip headers
            if f>1
              s = "#{tr.css('td/text()')[0].to_s.strip.upcase}"
              next if s != fn[1][0]
              s = "#{tr.css('td/text()')[1].to_s.strip.upcase}"
              next if s[0,3]=='SPO'
              break if !fmon.has_key?(s[0,3])
              mn = fmon[s[0,3]].to_s
              yr = '20' + s[3,2]
              cd = fn[1][0]
              ex = fn[1][1]
              ex = ex[1,3]
              printf "%s,%s,%s,%s,%s,", ex, cd, mn, yr, dt

              [2,3,4,6,9,10].each do |n|
                s = "#{tr.css('td/text()')[n].to_s.strip}"
                s.gsub!(/[A-Z]|,/,'')
                x=s
                x=0 if x == '/'
                case n
                when 2
                  record[:open] = x.to_f
                when 3
                  record[:high] = x.to_f
                when 4
                  record[:low] = x.to_f
                when 6
                  record[:settle] = x.to_f
                when 9
                  record[:volume] = x.to_f
                when 10
                  record[:interest] = x.to_f
                end
                printf "%s", x
                print "," if n!=10
              end
              add_to_database(ex,cd,yr,mn,dt,record)
              print "\n"
              $stdout.flush
            end
            f+=1
          end  #rows
        end  #table
      end  #fnames
      
      #update CFC for the newly added data
      Asset.all.each do |asset|
        #first make cfc associations for all today's new entries
        next if asset.name.nil?
        puts "Updating CFC for " + asset.symbol
        the_rows = asset.future_data_rows.where(:date => input_date).sort {|row1,row2| row1.future.date_obj <=> row2.future.date_obj}
        the_rows.each_with_index do |the_row,i|
          depth = i + 1
          puts "Expiry: " + the_row.future.month + the_row.future.year.to_s if asset.symbol == "AD"
          puts "Depth: " + depth.to_s if asset.symbol == "AD"
          target_cfc = Cfc.where(:asset_id => the_row.asset.id,:depth => depth).first
          if target_cfc
            puts "Target id: " + target_cfc.id if asset.symbol = "AD"
            puts "Depth of target: " + target_cfc.depth.to_s if asset.symbol == "AD"
            the_row.cfc = target_cfc
            the_row.save
            puts "New cfc id: " + the_row.cfc_id.to_s if asset.symbol == "AD"
          else
            the_row.create_cfc(:asset_id => the_row.asset.id,:depth => depth)
          end
          puts "Asset: " + the_row.asset.id.to_s + " Date: " + the_row.date.to_s + " Depth: " + (depth).to_s
        end
        
        #now fix previous depths in cfcs according to the new data
        #cycle through each cfc starting with front month
        asset.cfcs.order("depth asc").each do |cfc|
          puts "Verifying " + cfc.asset.symbol + cfc.depth.to_s
          the_rows = cfc.future_data_rows.order("date desc")
          #cycle through its rows starting with the freshest data before today
          the_rows.each_index do |i|
            next if i == 0
            #for each row, if the future expiry date is further in the future than that of today's new addition, increase it's depth
            #then check out the next row
            if the_rows.first.future.date_obj < the_rows[i].future.date_obj
              the_rows[i].increase_depth
              puts "Increased depth of row with id " + the_rows[i].id.to_s
            else
              #if one row is clean we can break because so should be all following rows.
              #this if condition exists in case we are dealing with a row that has just had its
              #depth increased from another cfc, then we will have two rows with the same date and 
              #must check both.
              if the_rows[i+1].nil?
                puts "CFC clean"
                break
              else
                if the_rows[i].date != the_rows[i+1].date
                  puts "CFC clean"
                  break
                end
              end
            end
          end
        end
      end
      
    end #task
  end
  
  namespace :update do
    desc "create associations between the future data rows and the cfc table"
    task :cfc, [:asset] => :environment do
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
    namespace :history do
      desc "Scrape the history of the LBMA gold and silver, fixings and forwards"
      task :lbma => :environment do
      end
      
      desc "Scrape the history of the LME for non-precious metal data"
      task :lbma => :environment do
      end
    end
    namespace :single do
      desc "Scrape the LBMA gold and silver, fixings and forwards for the given date"
      task :lbma => :environment do
      end
      
      desc "Scrape the LME for non-precious metal data for the given date"
      task :lbma => :environment do
      end
    end
  end
end