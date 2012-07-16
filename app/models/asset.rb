class Asset < ActiveRecord::Base
  attr_accessible :symbol, :name, :exchange
  has_many :futures
end