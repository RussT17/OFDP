class StockOptionDataRow < ActiveRecord::Base
  attr_accessible :stock_option, :stock_option_id,:date,:last_trade_price,:change,:bid,:ask,:volume,:open_interest
  belongs_to :stock_option
end