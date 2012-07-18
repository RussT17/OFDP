class MetalDataset < ActiveRecord::Base
  attr_accessible :id,:metal_id,:table,:name
  belongs_to :metal
  
  def data_rows
    return NonPrecPrice.where(:metal_dataset_id => @id) if @table == "non_prec_prices"
    return PreciousForward.where(:metal_dataset_id => @id) if @table == "precious_forwards"
    return PreciousFixing.where(:metal_dataset_id => @id) if @table == "precious_fixings"
  end
  
  def create_data_row(hash)
    hash[:metal_dataset_id] = @id
    return NonPrecPrice.create(hash) if @table == "non_prec_prices"
    return PreciousForward.create(hash) if @table == "precious_forwards"
    return PreciousFixing.create(hash) if @table == "precious_fixings"
  end
end