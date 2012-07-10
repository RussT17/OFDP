namespace :options do
  namespace :scrape do
    desc "Scrape Yahoo Finance for options data for all ticker symbols in the table"
    task :yahoo => :environment do
      require 'net/http'
      require 'uri'
      require 'json'
      Stock.pluck('symbol').each do |ticker_symbol|
        url = 'http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.options%20where%20symbol%20in%20(%22' + \
          ticker_symbol + '%22)&format=json&diagnostics=true&env=http%3A%2F%2Fdatatables.org%2Falltables.env&callback='
        uri = URI.parse(url)
        response = Net::HTTP.get_response(uri)
        options = JSON.parse(response.body)["query"]["results"]["optionsChain"]["option"]
        options.each do |option|
          #STORE NECESSARY INFO IN DATABASE
        end
      end
    end
  end
end