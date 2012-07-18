class Metal < ActiveRecord::Base
  attr_accessible :name,:source
  has_many :metal_datasets, :dependent => :destroy
end