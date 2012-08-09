class InvalidContractMonth < ActiveRecord::Base
  attr_accessible :asset,:asset_id,:month
  belongs_to :asset
end