class StockOptionDataRow < ActiveRecord::Base
  attr_accessible :stock_option,:date,:last_trade_price,:change,:bid,:ask,:volume,:open_interest
  belongs_to :stock_option
end