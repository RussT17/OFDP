require 'date'

desc "Everything is combined into a big scrape starting at 3:00am UTC"
task :scrape => :environment do
  date = Date.today-1
  
  if ![0,6].include? date.wday #check that yesterday wasn't a weekend day
    puts "Options:"
    begin
      scraper = OptionScraper.new
      scraper.scrape(date)
      scraper.add_to_database
    rescue => e
      RakeErrorMessage.create(:message => e.message, :backtrace => e.backtrace.join("\n"))
    end
  end
  
  #for precaution we run the metals whether it was a weekday or not
  puts "\nPrecious Metal Fixings:"
  begin
    scraper = PreciousFixingScraper.new
    scraper.scrape_on(date)
    scraper.add_to_database
  rescue => e
    RakeErrorMessage.create(:message => e.message, :backtrace => e.backtrace.join("\n"))
  end
  
  puts "\nPrecious Metal Forwards:"
  begin
    scraper = PreciousForwardScraper.new
    scraper.scrape_on(date)
    scraper.scrape_on(date-15)
    scraper.add_to_database
  rescue => e
    RakeErrorMessage.create(:message => e.message, :backtrace => e.backtrace.join("\n"))
  end
  
  puts "\nNonprecious Metal Prices:"
  begin
    scraper = NonpreciousScraper.new
    scraper.scrape
    scraper.add_to_database
  rescue => e
    RakeErrorMessage.create(:message => e.message, :backtrace => e.backtrace.join("\n"))
  end
  
  #FUTURES - only run on weekdays
  date1 = Date.today-1
  date1_good = (![0,6].include? date1.wday)
  date2 = date1 - 1
  date2_good = (![0,6].include? date2.wday)
  puts "Futures:"
  begin
    scraper = FutureScraper.new
    if date1_good
      scraper.add_source(:eur, date1)
      scraper.add_source(:cme, date1)
      scraper.add_source(:ice, date1)
      scraper.add_source(:icu, date1)
    end
    if date2_good
      scraper.add_source(:cme, date2)
      scraper.add_source(:ice, date2)
      scraper.add_source(:icu, date2)
    end
    scraper.full_run
  rescue => e
    RakeErrorMessage.create(:message => e.message, :backtrace => e.backtrace.join("\n"))
  end
  
  begin
    scraper = IndexScraper.new
    scraper.scrape_dryships
    scraper.add_to_database
  rescue => e
    RakeErrorMessage.create(:message => e.message, :backtrace => e.backtrace.join("\n"))
  end
  
  #if it's saturday do the weekly scrape on CFTC
  date = Date.today
  if date.wday == 0
    begin
      scraper = CotScraper.new
      scraper.scrape_newest_before(date)
      scraper.add_to_database
    rescue => e
      RakeErrorMessage.create(:message => e.message, :backtrace => e.backtrace.join("\n"))
    end
  end
end