class Index < ActiveRecord::Base
  attr_accessible :name
  has_many :index_data_rows, :dependent => :destroy
end