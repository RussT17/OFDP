class FuturesDataRow < ActiveRecord::Base
  attr_accessible :dt, :exchange, :high, :interest, :low, :month, :open, :settle, :ticker, :volume, :year
end
