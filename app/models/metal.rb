class Metal < ActiveRecord::Base
  attr_accessible :name,:source,:data_path
  has_many :metal_datasets, :dependent => :destroy
end