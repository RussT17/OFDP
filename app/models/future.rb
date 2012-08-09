class Future < ActiveRecord::Base
  attr_accessible :asset,:asset_id,:month,:year
  belongs_to :asset
  has_many :future_data_rows, :dependent => :destroy
  
  def date_obj
    Date.parse(self.year.to_s + ' ' + Ofdp::Application::MONTH_NAMES[self.month])
  end
  
  def self.purge_invalid
    #Destroys futures where the contract month is in the invalid_contract_months table
    self.all.each do |future|
      bad_months = future.asset.invalid_contract_months.map{|row| row.month}
      if bad_months.include? future.month
        puts future.asset.symbol + future.month + future.year.to_s
        future.destroy
      end
    end
  end
end