class FutureDataRow < ActiveRecord::Base
  attr_accessible :future_id,:date,:open,:high,:low,:settle,:volume,:interest,:front_rank
  belongs_to :future
  belongs_to :cfc
  
  def asset
    future.asset
  end
  
  def increase_depth
    current_depth = self.cfc.depth
    asset_id = self.cfc.asset_id
    target_cfc = Cfc.where(:asset_id => asset_id,:depth => current_depth + 1).first
    if target_cfc
      self.cfc = target_cfc
    else
      self.create_cfc(:asset_id => asset_id,:depth => current_depth + 1)
    end
  end
end