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
            FuturesContent.where(:exchange => ex, :ticker => cd, :month => mn, :year => yr).first_or_create
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
            FuturesContent.where(:exchange => ex, :ticker => cd, :month => mn, :year => yr).first_or_create
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

desc "update table of contents based on current data"
task :update_contents => :environment do
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

desc "update choices based on current data"
task :update_choices => :environment do
  puts "Updating dropdown choices..."
  #now update dropdown choices
  #first clear old choie table
  FuturesChoice.delete_all
  
  #now add new choices
  fields = ['ticker','month','year','exchange']
  fields.each do |field|
    choices = FuturesDataRow.uniq.pluck(field).sort
    choices.each {|choice| FuturesChoice.create(:choice => choice, :type => field)}
  end
  puts "Done."
end

desc "update choices and contents"
task :update_all => [:update_choices,:update_contents]
end