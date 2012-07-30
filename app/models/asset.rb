class Asset < ActiveRecord::Base
  attr_accessible :symbol, :name, :exchange
  has_many :futures, :dependent => :destroy
  has_many :future_data_rows, :through => :futures
  has_many :cfcs, :dependent => :destroy
  has_many :invalid_contract_months, :dependent => :destroy
  
  def update_cfc_on(input_date)
    #does a single date in the asset's history
    #first make cfc associations for all today's new entries
    puts "Updating CFC for " + self.symbol + ' based on data updated for ' + input_date.to_s
    the_rows = self.future_data_rows.where(:date => input_date).sort {|row1,row2| row1.future.date_obj <=> row2.future.date_obj}
    the_rows.each_with_index do |the_row,i|
      depth = i + 1
      target_cfc = self.cfcs.where(:depth => depth).first_or_create
      the_row.cfc = target_cfc
      the_row.save
      puts "Asset: " + self.id.to_s + " Date: " + the_row.date.to_s + " Depth: " + (depth).to_s
    end
    #now fix previous depths in cfcs according to the new data
    #cycle through each cfc starting with front month
    self.cfcs.order("depth asc").each do |cfc|
      puts "Verifying " + self.symbol + cfc.depth.to_s + ' around ' + input_date.to_s
      #only fixes errors from the last 30 days
      the_rows = cfc.future_data_rows.where("date > ?",input_date - 30).where("date <= ?",input_date + 1).order("date desc")
      next if the_rows.empty?
      #cycle through these rows
      earliest_expiry = the_rows[0].future.date_obj
      the_rows.each_index do |i|
        next if i == 0
        if earliest_expiry < the_rows[i].future.date_obj
          the_rows[i].increase_depth
        else
          break if the_rows[i].date < input_date
          earliest_expiry = the_rows[i].future.date_obj
        end
      end
    end
  end
  
  def update_cfc
    #works for all history of the asset
    self.future_data_rows.order("date desc").uniq.pluck(:date).each do |date|
      the_rows = self.future_data_rows.where(:date => date).sort {|row1,row2| row1.future.date_obj <=> row2.future.date_obj}
      bump_count = 0
      the_rows.each_with_index do |the_row,i|
        depth = i + 1
        if !the_row.cfc_id.nil?
          next_row = the_row.cfc.future_data_rows.where("date > ?", date).order("date asc").first
        end
        if !next_row.nil?
          if next_row.future.date_obj < the_row.future.date_obj
            bump_count = bump_count + 1
          end
        end
        depth = depth + bump_count
        target_cfc = Cfc.where(:asset_id => self.id,:depth => depth).first
        if target_cfc
          the_row.cfc = target_cfc
          the_row.save
        else
          the_row.create_cfc(:asset_id => self.id,:depth => depth)
        end
        puts "Asset: " + self.id.to_s + " Date: " + the_row.date.to_s + " Depth: " + (depth).to_s
      end
    end
  end
end