class Future < ActiveRecord::Base
  attr_accessible :asset,:asset_id,:month,:year, :is_valid
  belongs_to :asset
  has_many :future_data_rows, :dependent => :destroy
  
  def date_obj
    Date.parse(self.year.to_s + ' ' + Ofdp::Application::MONTH_NAMES[self.month])
  end
  
  def validate
    bad_months = self.asset.invalid_contract_months.map{|row| row.month}
    is_valid = (!bad_months.include? self.month)
    self.update_attributes(is_valid: is_valid)
  end
end