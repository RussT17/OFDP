class IndexDataRow < ActiveRecord::Base
  attr_accessible :date, :value, :index, :index_id
  belongs_to :index
end