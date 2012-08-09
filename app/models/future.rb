class Future < ActiveRecord::Base
  attr_accessible :asset,:asset_id,:month,:year
  belongs_to :asset
  has_many :future_data_rows, :dependent => :destroy
  
  def date_obj
    Date.parse(self.year.to_s + ' ' + Ofdp::Application::MONTH_NAMES[self.month])
  end
  
  def valid?
    bad_months = self.asset.invalid_contract_months.map{|row| row.month}
    !bad_months.include? self.month
  end
end