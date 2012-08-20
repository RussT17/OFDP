class Cot < ActiveRecord::Base
  attr_accessible :name, :desc, :legacy
  has_many :cot_data_rows, :dependent => :destroy
end