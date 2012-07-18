class BadFutureDataRow < ActiveRecord::Base
  attr_accessible :symbol, :exchange, :year, :month, :date, :open, :high, :low, :settle, :volume, :interest
end