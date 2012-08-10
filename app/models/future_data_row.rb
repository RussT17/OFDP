class FutureDataRow < ActiveRecord::Base
  attr_accessible :future,:future_id,:date,:open,:high,:low,:settle,:volume,:interest,:cfc,:cfc_id
  belongs_to :future
  belongs_to :cfc
  
  def asset
    future.asset
  end
  
  def set_cfc(depth)
    self.cfc = Cfc.where(asset_id: self.future.asset_id, depth: depth).first_or_create
    self.save
    self.cfc
  end
  
  def validate_cfc
    return if self.cfc_id == nil
    the_cfc = self.cfc
    #now validate previous rows (from past 30 days, we will probably only ever go two or three days though)
    previous_rows = self.cfc.future_data_rows.where("date < ?",self.date).where("date > ?", self.date-30).order("date DESC")
    if previous_rows.length >= 3
      newest_future = self.future
      newest_expiry = newest_future.date_obj
      if previous_rows[0].future.date_obj == newest_expiry and previous_rows[1].future.date_obj != newest_expiry
        #with this if condition we have exactly two-in-a-row records with the same front month expiry
        current_row_expiry = previous_rows[1].future.date_obj
        previous_rows[1..-2].each_index do |i|
          next_row_expiry = previous_rows[i+1].future.date_obj
          if current_row_expiry != next_row_expiry
            next if current_row_expiry == newest_expiry
            puts "Misplaced row, id: #{previous_rows[i].id.to_s}"
            previous_rows[i].update_attributes(cfc_id: nil)
            replacement_row = newest_future.future_data_rows.where(date: previous_rows[i].date).first
            replacement_row.cfc = the_cfc
            replacement_row.save
          else
            break
          end
          current_row_expiry = next_row_expiry
        end
      end
    end
    the_cfc
  end
end