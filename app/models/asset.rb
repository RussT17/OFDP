class Asset < ActiveRecord::Base
  attr_accessible :symbol, :name, :exchange
  has_many :futures
  has_many :future_data_rows, :through => :futures
  has_many :cfcs
end