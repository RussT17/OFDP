class StockOption < ActiveRecord::Base
  attr_accessible :stock,:expiry_date,:is_call,:strike_price,:symbol
  belongs_to :stock
  has_many :stock_option_data_rows, :dependent => :destroy
end