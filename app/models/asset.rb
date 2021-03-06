class Asset < ActiveRecord::Base
  attr_accessible :symbol, :name, :exchange
  has_many :futures, :dependent => :destroy
  has_many :future_data_rows, :through => :futures
  has_many :cfcs, :dependent => :destroy

  def update_cfcs_on(input_date)
    #first update cfc1 for this new date
    update_cfc1_on(input_date)
    
    #now, just for the most recent front month change period, update all the other cfcs
    the_cfc = self.cfcs.where(depth: 1).first
    front_rows = the_cfc.future_data_rows
    last_change = front_rows.minimum(:date, :group => :future_id).to_hash.max_by{|k,v| v}
    cfc1_future = Future.find(last_change[0])
    
    futures = self.futures.reject{|f| f.date_obj <= cfc1_future.date_obj}.sort{|f1,f2| f1.date_obj <=> f2.date_obj}
    futures.each_with_index do |f,i|
      rows = f.future_data_rows.where("date >= ?", last_change[1])
      next if rows.empty?
      rows.each do |row|
        row.set_cfc(i+2)
      end
    end
  end

  def update_cfc1_on(input_date)
    front_row = (self.future_data_rows.where(date: input_date).sort {|row1,row2| row1.future.date_obj <=> row2.future.date_obj})[0]
    if !front_row.nil?
      front_row.set_cfc(1)
      front_row.validate_cfc
    end
  end
  
  def calculate_cfcs
    #See WARNINGS on the functions called by this function
    
    build_cfc1
    build_deeper_cfcs
  end
  
  def build_cfc1
    #WARNING: Assumes all CFC_IDs for future_data_rows in CFC1 are set to nil before beginning. Make sure this happens first.
    
    rows = self.future_data_rows
    start_date = rows.minimum('date')
    end_date = rows.maximum('date')

    #First determine the cfc of depth 1
    (start_date..end_date).each do |date|
      update_cfc1_on(date)
    end
  end
  
  def build_deeper_cfcs
    #WARNING: Assumes all CFC_IDs for future_data_rows in CFC2 and up are set to nil before beginning. Make sure this happens first.
    
    #Figure out the dates when the front month changes
    the_cfc = self.cfcs.where(depth: 1).first
    front_rows = the_cfc.future_data_rows
    future_change_dates = front_rows.minimum(:date, :group => :future_id).to_a.map{|arr| {future: Future.find(arr[0].to_i), date: arr[1]}}.sort{|hash1,hash2| hash1[:date] <=> hash2[:date]}
    
    #Find the definitive list of ordered future contracts for this asset
    futures = self.futures.sort {|f1,f2| f1.date_obj <=> f2.date_obj}
    
    #Now tack these two future lists together, that is, create a new list which begins with the futures from future_change_dates
    #and then, when that runs out, resort to the (potentially less accurate) futures list from above.
    fut_order = future_change_dates.map{|hash| hash[:future]} + futures[(futures.index(future_change_dates[-1][:future]) + 1)..-1]
    
    #Now for each chunk in the continuous contract history, build the deeper cfcs using the order from above.
    #Note: One time one of the american futures sources reported extra future contracts with unusual expiry months. This could ruin
    #a cfc for a front month period, but would be fixed down the road if this function was rerun later, once in the invalid contract
    #had passed it's expiry date, since it never would have become a front month.
    future_change_dates.each_index do |i|
      h1 = future_change_dates[i]
      h2 = future_change_dates[i+1]
      if !h2.nil?
        fut_order[i+1..-1].each_with_index do |f,i|
          rows = f.future_data_rows.where("date >= ?", h1[:date]).where("date < ?", h2[:date])
          next if rows.empty?
          rows.each do |row|
            row.set_cfc(i+2)
          end
        end
      else
        fut_order[i+1..-1].each_with_index do |f,i|
          rows = f.future_data_rows.where("date >= ?", h1[:date])
          next if rows.empty?
          rows.each do |row|
            row.set_cfc(i+2)
          end
        end
      end
    end
  end
end