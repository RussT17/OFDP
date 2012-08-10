class Future < ActiveRecord::Base
  attr_accessible :asset,:asset_id,:month,:year
  belongs_to :asset
  has_many :future_data_rows, :dependent => :destroy
  
  def date_obj
    Date.parse(self.year.to_s + ' ' + Ofdp::Application::MONTH_NAMES[self.month])
  end
end