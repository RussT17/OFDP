require "nokogiri"
require "open-uri"
require "typhoeus"
require "date"

#SCRAPE: Input any date, no limit on archives
#HISTORY: Full history available
#Running an invalid date is okay and will not submit any records. No duplicates will be made.

class PreciousFixingScraper
  def initialize
    @new_entries = Array.new
  end
  
  def scrape_on(date)
    #Gold Fixings
    the_metal = Metal.where(:name=>'Gold').first
    the_am_dataset = the_metal.metal_datasets.where(:name => 'London Fixings A.M.').first
    the_pm_dataset = the_metal.metal_datasets.where(:name => 'London Fixings P.M.').first
    url = "http://www.lbma.org.uk/pages/index.cfm?page_id=53&title=gold_fixings&show=" + date.year.to_s + "&type=daily"
    doc = Nokogiri::HTML(open(url))
    table = doc.css('table.pricing_detail')
    table.css('tr').to_a.each do |row|
      row_data = Array.new
      row.css('*:not(a)').each_with_index do |cell,i|
        row_data[i] = cell.content
      end
      next if row_data[0] == ""
      #since website uses two digit years which confuse ruby, let's sub in our
      #four digit years instead
      row_data[0] = row_data[0][0,row_data[0].length-2] + date.year.to_s
      #check if this is the correct date!
      begin
        next if Date.parse(row_data[0]) != date
      rescue
        next
      end
      #turn blank entries and words like "day off for christmas" into nil cells
      row_data.each_index do |j|
        next if j == 0
        temp = /[0-9.]+/.match(row_data[j]).to_s
        row_data[j] = temp != "" ? temp.to_f : nil
      end
      if !row_data[1,3].compact.empty?
        entry = Entry.new
        entry.metal_dataset = the_am_dataset
        entry.date = date
        entry.usd = row_data[1]
        entry.gbp = row_data[2]
        entry.eur = row_data[3]
        entry.save
        @new_entries << entry
      end
      if !row_data[4,6].compact.empty?
        entry = Entry.new
        entry.metal_dataset = the_pm_dataset
        entry.date = date
        entry.usd = row_data[4]
        entry.gbp = row_data[5]
        entry.eur = row_data[6]
        entry.save
        @new_entries << entry
      end
      break
    end
    
    #Silver Fixings
    the_dataset = Metal.where(:name=>'Silver').first.metal_datasets.where(:name => 'London Fixings').first
    url = "http://www.lbma.org.uk/pages/index.cfm?page_id=54&title=silver_fixings&show=" + date.year.to_s + "&type=daily"
    doc = Nokogiri::HTML(open(url))
    table = doc.css('table.pricing_detail')
    table.css('tr').to_a.each do |row|
      row_data = Array.new
      row.css('*:not(a)').each_with_index do |cell,i|
        row_data[i] = cell.content
      end
      next if row_data[0] == ""
      #since website uses two digit years which confuse ruby, let's sub in our
      #four digit years instead
      row_data[0] = row_data[0][0,row_data[0].length-2] + date.year.to_s
      #check if this is the correct date!
      begin
        next if Date.parse(row_data[0]) != date
      rescue
        next
      end
      #turn blank entries and words like "day off for christmas" into nil cells
      row_data.each_index do |j|
        next if j == 0
        temp = /[0-9.]+/.match(row_data[j]).to_s
        row_data[j] = temp != "" ? temp.to_f : nil
      end
      1.upto(3) {|i| row_data[i] = row_data[i]/100 if !row_data[i].nil?}
      if !row_data[1,3].compact.empty?
        entry = Entry.new
        entry.metal_dataset = the_dataset
        entry.date = date
        entry.usd = row_data[1]
        entry.gbp = row_data[2]
        entry.eur = row_data[3]
        entry.save
        @new_entries << entry
      end
      break
    end
  end
  
  def scrape_history
    #Gold first
    
    #First prepare Typhoeus
    hydra = Typhoeus::Hydra.new
    requests = Array.new
    1968.upto(Date.today.year) do |year|
      index = year-1968
      url = "http://www.lbma.org.uk/pages/index.cfm?page_id=53&title=gold_fixings&show=" + year.to_s + "&type=daily"
      requests[index] = Typhoeus::Request.new(url)
      hydra.queue(requests[index])
    end
    puts "Starting hydra"
    hydra.run
    puts "Hydra finished"
    
    the_metal = Metal.where(:name=>'Gold').first
    the_am_dataset = the_metal.metal_datasets.where(:name => 'London Fixings A.M.').first
    the_pm_dataset = the_metal.metal_datasets.where(:name => 'London Fixings P.M.').first
    1968.upto(Date.today.year) do |year|
      index = year-1968
      url = "http://www.lbma.org.uk/pages/index.cfm?page_id=53&title=gold_fixings&show=" + year.to_s + "&type=daily"
      doc = Nokogiri::HTML(requests[index].response.body)
      table = doc.css('table.pricing_detail')
      table.css('caption').remove
      header = table.css('thead:nth-child(1)').remove
      numcols = header.css('tr:nth-child(2) th').to_a.length
      table.css('tr').to_a.each do |row|
        row_data = Array.new
        row.css('*:not(a)').each_with_index do |cell,i|
          row_data[i] = cell.content
        end
        next if row_data[0] == ""
        #since website uses two digit years which confuse ruby, let's sub in our
        #four digit years instead
        row_data[0] = row_data[0][0,row_data[0].length-2] + year.to_s
        #turn blank entries and words like "day off for christmas" into nil cells
        row_data.each_index do |j|
          next if j == 0
          temp = /[0-9.]+/.match(row_data[j]).to_s
          row_data[j] = temp != "" ? temp.to_f : nil
        end
        if numcols == 5
          if !row_data[1,2].compact.empty?
            entry = Entry.new
            entry.metal_dataset = the_am_dataset
            entry.date = Date.parse(row_data[0])
            entry.usd = row_data[1]
            entry.gbp = row_data[2]
            entry.save
            @new_entries << entry
          end
          if !row_data[3,4].compact.empty?
            entry = Entry.new
            entry.metal_dataset = the_pm_dataset
            entry.date = Date.parse(row_data[0])
            entry.usd = row_data[3]
            entry.gbp = row_data[4]
            entry.save
            @new_entries << entry
          end
        end
        if numcols == 7
          if !row_data[1,3].compact.empty?
            entry = Entry.new
            entry.metal_dataset = the_am_dataset
            entry.date = Date.parse(row_data[0])
            entry.usd = row_data[1]
            entry.gbp = row_data[2]
            entry.eur = row_data[3]
            entry.save
            @new_entries << entry
          end
          if !row_data[4,6].compact.empty?
            entry = Entry.new
            entry.metal_dataset = the_pm_dataset
            entry.date = Date.parse(row_data[0])
            entry.usd = row_data[4]
            entry.gbp = row_data[5]
            entry.eur = row_data[6]
            entry.save
            @new_entries << entry 
          end
        end
      end
    end
    
    #Now silver
    
    #First prepare Typhoeus
    hydra = Typhoeus::Hydra.new
    requests = Array.new
    1968.upto(Date.today.year) do |year|
      index = year-1968
      url = "http://www.lbma.org.uk/pages/index.cfm?page_id=54&title=silver_fixings&show=" + year.to_s + "&type=daily"
      requests[index] = Typhoeus::Request.new(url)
      hydra.queue(requests[index])
    end
    puts "Starting hydra"
    hydra.run
    puts "Hydra finished"
    
    the_dataset = Metal.where(:name=>'Silver').first.metal_datasets.where(:name => 'London Fixings').first
    1968.upto(Date.today.year) do |year|
      next if year == 1997 #NO DATES FOR THIS YEAR, PERHAPS THEY HAVE FIXED THE ERROR
      index = year-1968
      doc = Nokogiri::HTML(requests[index].response.body)
      table = doc.css('table.pricing_detail')
      table.css('caption').remove
      while !table.css('thead:first-of-type').empty?
        header = table.css('thead:first-of-type').remove
      end
      numcols = header.css('tr:last-of-type th').to_a.length
      table.css('tr').to_a.each do |row|
        row_data = Array.new
        row.css('*:not(a)').each_with_index do |cell,i|
          row_data[i] = cell.content
        end
        next if row_data[0] == ""
        #since website uses two digit years which confuse ruby, let's sub in our
        #four digit years instead
        row_data[0] = row_data[0][0,row_data[0].length-2] + year.to_s
        #turn blank entries and words like "day off for christmas" into nil cells
        row_data.each_index do |j|
          next if j == 0
          temp = /[0-9.]+/.match(row_data[j]).to_s
          row_data[j] = temp != "" ? temp.to_f : nil
        end
        1.upto(3) {|i| row_data[i] = row_data[i]/100 if !row_data[i].nil?}
        entry = Entry.new
        entry.metal_dataset = the_dataset
        entry.date = Date.parse(row_data[0])
        entry.usd = row_data[1]
        entry.gbp = row_data[2]
        if numcols == 3
          if !row_data[1,2].compact.empty?
            entry.save
            @new_entries << entry
          end
        end
        if numcols == 4 
          if !row_data[1,3].compact.empty?
            entry.eur = row_data[3]
            entry.save
            @new_entries << entry
          end
        end
      end
    end
  end
  
  def add_to_database(insert = false)
    @new_entries.delete_if do |entry|
      entry.submit(insert)
      true
    end
  end
  
  private
  
  class Entry < DataEntry
    entry_attr_accessor :metal_dataset, :date, :usd, :gbp, :eur
    
    def to_s
      @record.select{|k| [:metal_dataset, :date].include? k}.to_s
    end
    
    def submit(insert)
      if !insert
        @record[:metal_dataset].first_or_create_data_row(:date => @record[:date]).update_attributes(:usd => @record[:usd], :gbp => @record[:gbp], :eur => @record[:eur])
      else
        @record[:metal_dataset].create_data_row(:date => @record[:date]).update_attributes(:usd => @record[:usd], :gbp => @record[:gbp], :eur => @record[:eur])
      end
      puts 'Entry ' + to_s + ' submitted'
    end
  end
end