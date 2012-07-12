#there is much repetition among the futures scrapers, refactoring into methods is in order

namespace :futures do
namespace :scrape do
  desc "scrape CME and related sources (CBT,CEC,NYM), update contents accordingly"
  task :cme, [:date] => :environment do |t, args|
    require 'rubygems'
    require 'nokogiri'
    require 'open-uri'
    require 'date'

    args.with_defaults(:date => Date.today-1)
    input_date = args.date
    
    fields = ['ticker','month','year','exchange']

    if input_date.wday == 0 || input_date.wday == 6
      puts "# input date is a weekend; doing nothing"
      exit
    end

    dt = input_date
    du = sprintf("%02d/%02d/%04d", input_date.month, input_date.day, input_date.year)

    ur = 'http://www.cmegroup.com/CmeWS/mvc/xsltTransformer.do?xlstDoc=/XSLT/da/DailySettlement.xsl&url=/da/DailySettlement/V1/DSReport/ProductCode/%s/FOI/FUT/EXCHANGE/%s/Underlying/%s'
    ur = ur + '?tradeDate=' + du

    fmon = { 'JAN' => 'F', 'FEB' => 'G', 'MAR' => 'H', 'APR' => 'J', 'MAY' => 'K', 'JUN' => 'M',
             'JLY' => 'N', 'AUG' => 'Q', 'SEP' => 'U', 'OCT' => 'V', 'NOV' => 'X', 'DEC' => 'Z' }

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
            FuturesDataRow.where(:dt => dt, :exchange => ex, :ticker => cd, :month => mn, :year => yr).first_or_create(record)
            FuturesContent.where(:exchange => ex, :ticker => cd, :month => mn, :year => yr).first_or_create unless TickerSymbol.where("symbol = '#{cd}'").where("exchange = '#{ex}'").length == 0
            $stdout.flush
          end
          f+=1
        end  #rows
      end  #table
    end  #fnames
  end
  
  
  
  desc "scrape ICE, update contents accordingly"
  task :ice, [:date] => :environment do |t,args|
    require 'rubygems'
    require 'nokogiri'
    require 'open-uri'
    require 'date'

    args.with_defaults(:date => Date.today-1)
    input_date = args.date
    
    fields = ['ticker','month','year','exchange']

    if input_date.wday == 0 || input_date.wday == 6
      puts "# input date is a weekend; doing nothing"
      exit
    end

    dt = input_date
    du = sprintf("%02d/%02d/%04d", input_date.month, input_date.day, input_date.year)

    ur = 'https://www.theice.com/marketdata/reports/icefutureseurope/EndOfDay.shtml?tradeDay=%d&tradeMonth=%d&tradeYear=%d&contractKey=%s'

    fmon = { 'JAN' => 'F', 'FEB' => 'G', 'MAR' => 'H', 'APR' => 'J', 'MAY' => 'K', 'JUN' => 'M',
             'JUL' => 'N', 'AUG' => 'Q', 'SEP' => 'U', 'OCT' => 'V', 'NOV' => 'X', 'DEC' => 'Z' }

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
            FuturesDataRow.where(:dt => dt, :exchange => ex, :ticker => cd, :month => mn, :year => yr).first_or_create(record)
            FuturesContent.where(:exchange => ex, :ticker => cd, :month => mn, :year => yr).first_or_create unless TickerSymbol.where("symbol = '#{cd}'").where("exchange = '#{ex}'").length == 0
            print "\n"
          $stdout.flush
          end
          f+=1
        end  #rows
      end  #table
    end  #fnames
  end
  


  
  desc "scrape ICU, update contents accordingly"
  task :icu, [:date] => :environment do |t,args|
    require 'rubygems'
    require 'nokogiri'
    require 'open-uri'
    require 'date'

    args.with_defaults(:date => Date.today-1)
    input_date = args.date
    
    fields = ['ticker','month','year','exchange']

    if input_date.wday == 0 || input_date.wday == 6
      puts "# input date is a weekend; doing nothing"
      exit
    end

    dt = input_date
    du = sprintf("%02d/%02d/%04d", input_date.month, input_date.day, input_date.year)

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
            FuturesDataRow.where(:dt => dt, :exchange => ex, :ticker => cd, :month => mn, :year => yr).first_or_create(record)
            FuturesContent.where(:exchange => ex, :ticker => cd, :month => mn, :year => yr).first_or_create unless TickerSymbol.where("symbol = '#{cd}'").where("exchange = '#{ex}'").length == 0
            print "\n"
            $stdout.flush
          end
          f+=1
        end  #rows
      end  #table
    end  #fnames
  end
  
  
  
  
    desc "scrape all sources"
    task :all => [:cme,:ice,:icu]
  end

  namespace :update do
    desc "update table of contents based on current data"
    task :contents => :environment do
      puts "Determining table of contents entries..."
  
      #first we'll update the table of contents
      contents = FuturesDataRow.select('ticker,month,year,exchange').uniq.map {|record| {:ticker => record.ticker, :month => record.month, :year => record.year, :exchange => record.exchange}}
      contents.delete_if {|c| TickerSymbol.where("symbol = '#{c[:ticker]}'").where("exchange = '#{c[:exchange]}'").length == 0}
  
      puts "Done."
      puts "Adding entries to database..."
  
      #clear old table of contents
      FuturesContent.delete_all
  
      #put new contents in the table of contents
      contents.each_index {|i| FuturesContent.create(contents[i])}
      puts "Done."
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
            option_record.stock_option_data_rows.where(:date => Date.today).first_or_create(:last_trade_price => option["lastPrice"], :change => option["change"], :bid => option["bid"], :ask => option["ask"], :volume => option["vol"], :open_interest => option["openInt"])
          end
          puts "Found #{options.length.to_s}"
        else
          puts "None found"
        end
      end
    end
  end
end