require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'date'
require 'typhoeus'

#The decision of which futures to scrape comes from the files in the lib/classes/codes folder.
#For all other data scrapers (metals and options) the list of items to scrape comes from the database.

#SCRAPE: Settlement prices, with a five-or-so day history to select from. Scrape too early and not all the
#data will necessarily be posted yet. Some assets' futures get posted up to a day late, so consider scraping for the two
#previous days each day. Sometimes the site reports futures with expiry months that don't exist. These are not displayed
#on the site but are stored in the database table bad_future_data_rows in case they are not just a glitch which
#is suspected. No harm running on a weekend, will do nothing.

#HISTORY: no built in history scraper since the history is not extensive.

#CFCs: Continuous Futures Contracts. Run update_cfcs AFTER adding to the database.

#full_run will do all your scraping, adding, and updating_cfcs in one function. Just add the sources with add_source
#and use full_run.

class FutureScraper
  def initialize
    @source_hashes = Array.new
    @new_entries = Array.new
    @submitted_entries = Array.new
  end
  
  def add_source(source_symbol,date = nil)
    raise ArgumentError.new('Source not recognized.') if ![:cme,:icu,:ice,:eur].include? source_symbol
    if [:cme,:icu,:ice,:eur].include? source_symbol
      raise ArgumentError.new('Date required to scrape this source.') if date.nil?
      raise ArgumentError.new('Provided date is a weekend.') if [0,6].include? date.wday and source_symbol != :eur
    end
    raise ArgumentError.new('Source/date combination already added') if @source_hashes.include?({:source => source_symbol, :date => date})
    @source_hashes << ({:source => source_symbol, :date => date})
  end
  
  def full_run
    scrape
    add_to_database
    update_cfcs
  end
  
  def scrape
    @source_hashes.each do |hash|
      puts "Scraping #{hash[:source].to_s.upcase} on #{hash[:date]}"
      case hash[:source]
      when :cme
        @new_entries += cme_entries(hash[:date])
      when :ice
        @new_entries += ice_entries(hash[:date])
      when :icu
        @new_entries += icu_entries(hash[:date])
      when :eur
        @new_entries += eur_entries
      end
    end
    @source_hashes = Array.new
    return nil
  end
  
  def add_to_database
    @new_entries.delete_if do |entry|
      entry.submit
      if entry.submitted?
        @submitted_entries << entry
        true
      else
        false
      end
    end
    return nil
  end
  
  def update_cfcs
    #only updates the cfcs if the asset has a proper name in the database
    updated_assets.each {|hash| hash[:asset].update_cfc_on(hash[:date]) if !hash[:asset].name.nil?}
    @submitted_entries = Array.new
  end
  
  private
  
  def updated_assets
    #returns an array of hashes with the asset and the modified date
    @submitted_entries.map{|entry| {:asset => entry.asset, :date => entry.date}}.uniq
  end
  
  def cme_entries(input_date)
    entries = Array.new
    
    fmon = { 'JAN' => 'F', 'FEB' => 'G', 'MAR' => 'H', 'APR' => 'J', 'MAY' => 'K', 'JUN' => 'M',
             'JLY' => 'N', 'AUG' => 'Q', 'SEP' => 'U', 'OCT' => 'V', 'NOV' => 'X', 'DEC' => 'Z' }

    dt = input_date
    du = sprintf("%02d/%02d/%04d", input_date.month, input_date.day, input_date.year)

    ur = 'http://www.cmegroup.com/CmeWS/mvc/xsltTransformer.do?xlstDoc=/XSLT/da/DailySettlement.xsl&url=/da/DailySettlement/V1/DSReport/ProductCode/%s/FOI/FUT/EXCHANGE/%s/Underlying/%s'
    ur = ur + '?tradeDate=' + du

    fnames = Hash.new     # exch.code => urlcode,outcode,exch,category,name
    File.open(Dir[Rails.root.join "lib/classes/codes/cmecodes"][0], "r") do |fp|
      while (s = fp.gets)
        next if s[0].chr == '#'
        a = s.split(',')
        break if a[0] == "\n"
        fnames[a[2]+'.'+a[0]] = [a[0].strip, a[1].strip, a[2].strip, a[3].strip, a[4].strip.chomp]
      end
      fp.close
    end
    #first load all the html documents with typhoeus
    hydra = Typhoeus::Hydra.new
    requests = Array.new
    fnames.each_with_index do |fn,i|
      url = sprintf(ur, fn[1][0], fn[1][2], fn[1][0])
      requests[i] = Typhoeus::Request.new(url)
      hydra.queue(requests[i])
    end
    puts "starting Hydra"
    hydra.run
    fnames.each_with_index do |fn,i|
      doc = Nokogiri::HTML(requests[i].response.body)
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
            entry = Entry.new
            entry.exchange = ex
            entry.symbol = cd
            entry.month = mn
            entry.year = yr
            entry.date = dt

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
                entry.open = x.to_f
              when 2
                entry.high = x.to_f
              when 3
                entry.low = x.to_f
              when 6
                entry.settle = x.to_f
              when 7
                entry.volume = x.to_f
              when 8
                entry.interest = x.to_f
              end
            end
            entry.save
            entries << entry
          end
          f+=1
        end  #rows
      end  #table
    end  #fnames
    return entries
  end #cme_entries
  
  def ice_entries(input_date)
    entries = Array.new
    
    fmon = { 'JAN' => 'F', 'FEB' => 'G', 'MAR' => 'H', 'APR' => 'J', 'MAY' => 'K', 'JUN' => 'M',
             'JUL' => 'N', 'AUG' => 'Q', 'SEP' => 'U', 'OCT' => 'V', 'NOV' => 'X', 'DEC' => 'Z' }

    dt = input_date

    ur = 'https://www.theice.com/marketdata/reports/icefutureseurope/EndOfDay.shtml?tradeDay=%d&tradeMonth=%d&tradeYear=%d&contractKey=%s'

    fnames = Hash.new     # exch.code => code,exch,category,name
    File.open(Dir[Rails.root.join "lib/classes/codes/icecodes"][0], "r") do |fp|
      while (s = fp.gets)
        next if s[0].chr=='#'
        a = s.split(',')
        break if a[0] == "\n"
        fnames[a[2].strip+'.'+a[1]] = [a[0].strip, a[1].strip, a[2].strip, a[3].strip, a[4].strip.chomp]
      end
    fp.close
    end
    #first load all the html documents with typhoeus
    hydra = Typhoeus::Hydra.new
    requests = Array.new
    fnames.each_with_index do |fn,i|
      url = sprintf(ur, input_date.day, input_date.month-1, input_date.year, fn[1][0])
      url.gsub!(/\^/,'%5E')
      requests[i] = Typhoeus::Request.new(url)
      hydra.queue(requests[i])
    end
    puts "Starting Hydra"
    hydra.run
    fnames.each_with_index do |fn,i|
      doc = Nokogiri::HTML(requests[i].response.body)
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
            entry = Entry.new
            entry.exchange = ex
            entry.symbol = cd
            entry.month = mn
            entry.year = yr
            entry.date = dt

            [1,2,3,4,7,11].each do |n|
              s = "#{tr.css('td/text()')[n].to_s.strip}"
              s.gsub!(/[A-Z]|,/,'')
              x=s
              case n
              when 1
                entry.open = x.to_f
              when 2
                entry.high = x.to_f
              when 3
                entry.low = x.to_f
              when 4
                entry.settle = x.to_f
              when 7
                entry.volume = x.to_f
              when 11
                entry.interest = x.to_f
              end
            end
            entry.save
            entries << entry
          end
          f+=1
        end  #rows
      end  #table
    end  #fnames
    return entries
  end
  
  def icu_entries(input_date)
    entries = Array.new
    
    dt = input_date

    ur = 'https://www.theice.com/marketdata/nybotreports/getFuturesDMRResults.do?commodityChoice=%s&tradeDay=%d&tradeMonth=%d&tradeYear=%d&venueChoice=Electronic'

    fmon = { 'JAN' => 'F', 'FEB' => 'G', 'MAR' => 'H', 'APR' => 'J', 'MAY' => 'K', 'JUN' => 'M',
             'JUL' => 'N', 'AUG' => 'Q', 'SEP' => 'U', 'OCT' => 'V', 'NOV' => 'X', 'DEC' => 'Z' }

    fnames = Hash.new     # exch.code => code,exch,category,name
    File.open(Dir[Rails.root.join "lib/classes/codes/icucodes"][0], "r") do |fp|
      while (s = fp.gets)
        next if s[0].chr=='#'
        a = s.split(',')
        break if a[0] == "\n"
        fnames[a[1]+'.'+a[0]] = [a[0].strip, a[1].strip, a[2].strip, a[3].strip.chomp]
      end
    fp.close
    end
    #first load all the html documents with typhoeus
    hydra = Typhoeus::Hydra.new
    requests = Array.new
    fnames.each_with_index do |fn,i|
      url = sprintf(ur, fn[1][0], input_date.day, input_date.month-1, input_date.year)
      url.gsub!(/\^/,'%5E')
      requests[i] = Typhoeus::Request.new(url)
      hydra.queue(requests[i])
    end
    puts "Starting Hydra"
    hydra.run
    fnames.each_with_index do |fn,i|
      doc = Nokogiri::HTML(requests[i].response.body)
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
            entry = Entry.new
            entry.exchange = ex
            entry.symbol = cd
            entry.month = mn
            entry.year = yr
            entry.date = dt

            [2,3,4,6,9,10].each do |n|
              s = "#{tr.css('td/text()')[n].to_s.strip}"
              s.gsub!(/[A-Z]|,/,'')
              x=s
              x=0 if x == '/'
              case n
              when 2
                entry.open = x.to_f
              when 3
                entry.high = x.to_f
              when 4
                entry.low = x.to_f
              when 6
                entry.settle = x.to_f
              when 9
                entry.volume = x.to_f
              when 10
                entry.interest = x.to_f
              end
            end
            entry.save
            entries << entry
          end
          f+=1
        end  #rows
      end  #table
    end  #fnames
    return entries
  end
  
  def eur_entries(input_date)
    max_concurrency = 100
    
    entries = Array.new
    assets = Array.new
    
    File.open(Dir[Rails.root.join "lib/classes/codes/eurexassets"][0],'r') do |file|
      file.each do |line|
        assets << eval(line)
      end
    end
    hydra = Typhoeus::Hydra.new(:max_concurrency => max_concurrency)
    assets.each do |asset|
      url = 'http://www.eurexchange.com/market/quotes/' + asset[:link] + '/' + asset[:symbol] + '.htm'
      asset[:request] = Typhoeus::Request.new(url, :headers => {'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:13.0) Gecko/20100101 Firefox/13.0.1'})
      hydra.queue(asset[:request])
    end
    puts "Starting hydra run 1"
    hydra.run
    puts "Hydra run 1 finished"
    
    assets.each do |asset|
      doc = Nokogiri::HTML(asset[:request].response.body)
      table = doc.css('div.content div.content table:nth-of-type(2)')
      expiries = Array.new
      table.css('tr.row-odd:not(:last-child)').each do |row|
        expiry = row.css('td:nth-child(2) a').first.content
        month = ('0' + Date.parse(expiry).month.to_s)[-2..-1]
        year = '20' + /[0-9]+/.match(expiry)[0]
        expiries << year + month
      end
      asset[:expiries] = expiries
    end
    
    hydra = Typhoeus::Hydra.new(:max_concurrency => max_concurrency)
    assets.each do |asset|
      asset[:data_requests] = Array.new
      asset[:expiries].each do |expiry|
        url = 'http://www.eurexchange.com/market/quotes/' + asset[:link] + '/' + asset[:symbol] + '/' + expiry + '.htm'
        asset[:data_requests] << Typhoeus::Request.new(url, :headers => {'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:13.0) Gecko/20100101 Firefox/13.0.1'})
        hydra.queue(asset[:data_requests][-1])
      end
    end
    puts "Starting hydra run 2"
    hydra.run
    puts "Hydra run 2 finished"
    
    assets.each do |asset|
      asset[:data_requests].each_with_index do |request,i|
        entry = Entry.new
        doc = Nokogiri::HTML(request.response.body)
        row = doc.css('div.content div.content table:nth-of-type(3) tr.row-odd')
        cells = row.css('td').to_a
        entry.open = cells[0].content.to_f
        entry.high = cells[1].content.to_f
        entry.low = cells[2].content.to_f
        entry.settle = cells[12].content.to_f
        entry.volume = cells[13].content.to_i
        entry.interest = cells[14].content.to_i
        entry.date = input_date
        entry.exchange = 'EUR'
        entry.symbol = asset[:symbol]
        entry.year = asset[:expiries][i][0..3]
        entry.month = Ofdp::Application::MONTH_NAMES.keys(asset[:expiries][i][4..5].to_i - 1)
        entry.save
        entries << entry
      end
    end
    return entries
  end
  
  class Entry < DataEntry
    def initialize
      @submitted = false
      @record = Hash.new
    end
    
    attr_reader :asset
    entry_attr_accessor :date, :exchange, :symbol, :year, :month, :open, :high, :low, :settle, :volume, :interest
    
    def submitted?
      @submitted
    end
    
    def to_s
      @record.select{|k| [:date,:exchange,:symbol,:month,:year].include? k}.to_s
    end
    
    def submit
      @asset = Asset.where(:exchange => @record[:exchange], :symbol => @record[:symbol]).first_or_create
      if @asset.invalid_contract_months.map{|row| row.month}.include? @record[:month]
        puts 'Entry ' + to_s + ' invalid'
        BadFutureDataRow.create(@record)
      else
        @future = @asset.futures.where(:year => @record[:year].to_i, :month => @record[:month]).first_or_create
        @data_row = @future.future_data_rows.where(:date => @record[:date]).first_or_create.update_attributes(@record.select {|k| [:open,:high,:low,:settle,:volume,:interest].include? k})
        puts 'Entry ' + to_s + ' submitted'
        @submitted = true
      end
    end
  end
end