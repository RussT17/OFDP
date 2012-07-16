class Future < ActiveRecord::Base
  attr_accessible :asset_id,:month,:year
  belongs_to :asset
  has_many :future_data_rows
end