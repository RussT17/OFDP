require 'json'
require 'typhoeus'

#The option scraper works differently than the future scraper. The list of which stocks to scrape options for does NOT
#come from a text file like it did for futures. Instead, the stocks table in the database is used.
#SCRAPE: Yahoo does not supply the date of the data given, so an entry_date must be specified. This is the date that will
#appear on the records in the database. The data is live and must be scraped at the end of the day after the market is closed.
#HISTORY: is not available.

class OptionScraper
  def initialize
    @new_entries = Array.new
  end
  
  def scrape(entry_date)
    #Unlike in FutureScraper, OptionScraper currently has only one source - yahoo finance.
    #entry_date will not affect the YQL query but only the date we put into the database
    
    #First get Typhoeus ready
    hydra = Typhoeus::Hydra.new
    requests = Array.new
    Stock.all.each_with_index do |stock,index|
      url = 'http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.options%20where%20symbol%20in%20(%22' + \
        stock.symbol + '%22)&format=json&diagnostics=true&env=http%3A%2F%2Fdatatables.org%2Falltables.env&callback='
      requests[index] = Typhoeus::Request.new(url)
      hydra.queue(requests[index])
    end
    puts "Starting hydra"
    hydra.run
    puts "Hydra finished"
    
    Stock.all.each_with_index do |stock,index|
      puts "Looking for #{stock.symbol} options"
      #send query to YQL a second time if the first attempt fails
      options = nil
      1.upto(2) do |i|
        begin
          if i == 2
            #second try
            hydra = Typhoeus::Hydra.new
            hydra.queue(requests[index])
            hydra.run
          end
          options = JSON.parse(requests[index].response.body)["query"]["results"]["optionsChain"]["option"]
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
          
          entry = Entry.new
          entry.option_symbol = option["symbol"]
          entry.expiry_date = expiry_date
          entry.is_call = is_call
          entry.strike_price = option["strikePrice"]
          entry.date = entry_date
          entry.last_trade_price = option["lastPrice"]
          entry.change = option["change"]
          entry.bid = option["bid"]
          entry.ask = option["ask"]
          entry.volume = option["vol"]
          entry.open_interest = option["openInt"]
          entry.stock = stock
          
          entry.save
          @new_entries << entry
        end
        puts "Found #{options.length.to_s}"
      else
        puts "None found"
      end
    end
  end
  
  def add_to_database
    @new_entries.delete_if do |entry|
      entry.submit
      true
    end
  end
  
  private
  
  class Entry < DataEntry
    entry_attr_accessor :stock, :expiry_date, :is_call, :strike_price, :option_symbol, :date, :last_trade_price, :change, :bid, :ask, :volume, :open_interest
    
    def to_s
      @record.select{|k| [:date,:option_symbol].include? k}.to_s
    end
    
    def submit
       option_record = @record[:stock].stock_options.where(:symbol => @record[:option_symbol]).first_or_create(:expiry_date => @record[:expiry_date],
          :is_call => @record[:is_call], :strike_price => @record[:strike_price])
       option_record.stock_option_data_rows.where(:date => @record[:date]).first_or_create.update_attributes(:last_trade_price => @record[:last_trade_price],
          :change => @record[:change], :bid => @record[:bid], :ask => @record[:ask], :volume => @record[:vol], :open_interest => @record[:open_interest])
    end
  end
end