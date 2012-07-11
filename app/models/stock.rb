class Stock < ActiveRecord::Base
  attr_accessible :symbol, :name, :exchange, :sector
  has_many :stock_options
end