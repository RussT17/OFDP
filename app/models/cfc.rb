class Cfc < ActiveRecord::Base
  attr_accessible :asset,:depth
  belongs_to :asset
  has_many :future_data_rows, :dependent => :nullify
  
  def self.purge_empty
    #deletes all CFCs that don't have any associated rows
    self.all.each do |cfc|
      cfc.destroy if cfc.future_data_rows.empty?
      puts cfc.asset + cfc.depth.to_s
    end
  end
end