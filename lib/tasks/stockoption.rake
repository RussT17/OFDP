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