class Stock < ActiveRecord::Base
  attr_accessible :symbol, :name, :exchange, :sector
end