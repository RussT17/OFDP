class MetalDataset < ActiveRecord::Base
  attr_accessible :id,:metal,:table,:name
  belongs_to :metal
  
  def data_rows
    return NonPrecPrice.where(:metal_dataset_id => self.id) if self.table == "non_prec_prices"
    return PreciousForward.where(:metal_dataset_id => self.id) if self.table == "precious_forwards"
    return PreciousFixing.where(:metal_dataset_id => self.id) if self.table == "precious_fixings"
  end
  
  def create_data_row(hash)
    hash[:metal_dataset_id] = self.id
    return NonPrecPrice.create(hash) if self.table == "non_prec_prices"
    return PreciousForward.create(hash) if self.table == "precious_forwards"
    return PreciousFixing.create(hash) if self.table == "precious_fixings"
  end
  
  def first_or_create_data_row(hash)
    hash[:metal_dataset_id] = self.id
    
    first = NonPrecPrice.where(hash).first if self.table == "non_prec_prices"
    first = PreciousForward.where(hash).first if self.table == "precious_forwards"
    first = PreciousFixing.where(hash).first if self.table == "precious_fixings"
    
    return first if !first.nil?
    
    return NonPrecPrice.create(hash) if self.table == "non_prec_prices"
    return PreciousForward.create(hash) if self.table == "precious_forwards"
    return PreciousFixing.create(hash) if self.table == "precious_fixings"
  end
end