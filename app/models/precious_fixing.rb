class PreciousFixing < ActiveRecord::Base
  attr_accessible :metal_dataset_id,:date,:usd,:gbp,:eur
  belongs_to :metal_dataset
end