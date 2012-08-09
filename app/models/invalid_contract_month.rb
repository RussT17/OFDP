class InvalidContractMonth < ActiveRecord::Base
  attr_accessible :asset,:month
  belongs_to :asset
end