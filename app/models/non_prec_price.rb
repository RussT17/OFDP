class NonPrecPrice < ActiveRecord::Base
  attr_accessible :metal_dataset_id,:date,:buyer,:seller,:mean
  belongs_to :metal_dataset
end