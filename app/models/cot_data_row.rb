class CotDataRow < ActiveRecord::Base
  attr_accessible :cot,:cot_id,:date,:data
  belongs_to :cot
end