class InvalidContractMonth < ActiveRecord::Base
  attr_accessible :asset_id,:month
  belongs_to :asset
end