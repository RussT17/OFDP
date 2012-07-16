class FutureDataRow < ActiveRecord::Base
  attr_accessible :future_id,:date,:open,:high,:low,:settle,:volume,:interest,:front_rank
  belongs_to :future
end