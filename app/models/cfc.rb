class Cfc < ActiveRecord::Base
  attr_accessible :asset_id,:depth
  belongs_to :asset
  has_many :future_data_rows, :dependent => :nullify
end