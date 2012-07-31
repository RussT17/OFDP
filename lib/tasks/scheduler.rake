# LIST of             SCRAPE TIMES (UTC) and DATE INPUTS (if applicable):

# AMERICAN FUTURES    04:30                  Date.today-1,Date.today-2
# EUREX FUTURES       ???                    ???
# OPTIONS             1:00                   Date.today-1
# PRECIOUS METALS     1:00                   Date.today-1
# NONPRECIOUS METALS  1:00                   N/A

require 'date'

desc "The 1:00am scrape, including options, precious metals, and nonprecious metals"
task :scrape1 => :environment do
  date = Date.today-1
  
  if ![0,6].include? date.wday #check that yesterday wasn't a weekend day
    scraper = OptionScraper.new
    scraper.scrape(date)
    scraper.add_to_database

    scraper = PreciousFixingScraper.new
    scraper.scrape_on(date)
    scraper.add_to_database

    scraper = PreciousForwardScraper.new
    scraper.scrape_on(date)
    scraper.scrape_on(date-20)
    scraper.add_to_database

    scraper = NonpreciousScraper.new
    scraper.scrape
    scraper.add_to_database
  end
end

desc "The 4:30am scrape, including American futures"
task :scrape2 => :environment do
  date1 = Date.today-1
  date2 = date1 - 1
  scraper = FutureScraper.new
  scraper.add_source(:cme, date1)
  scraper.add_source(:cme, date2)
  scraper.add_source(:ice, date1)
  scraper.add_source(:ice, date2)
  scraper.add_source(:icu, date1)
  scraper.add_source(:icu, date2)
  scraper.run_all
end