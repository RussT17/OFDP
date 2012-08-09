class NonPrecPrice < ActiveRecord::Base
  attr_accessible :metal_dataset, :metal_dataset_id,:date,:buyer,:seller
  belongs_to :metal_dataset
  
  def mean
    if !self.buyer.nil? and !self.seller.nil?
      return (self.buyer + self.seller)/2
    else
      return nil
    end
  end
end