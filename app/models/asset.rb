class Asset < ActiveRecord::Base
  attr_accessible :symbol, :name, :exchange
  has_many :futures, :dependent => :destroy
  has_many :future_data_rows, :through => :futures
  has_many :cfcs, :dependent => :destroy
  has_many :invalid_contract_months, :dependent => :destroy
end