require "nokogiri"
require "open-uri"
require "typhoeus"
require "date"

#SCRAPE: Input any date, no limit to archives. *important: the data row is half completed on the day of, but
# the second half of the row is only completed about 15 days later. Keep this in mind for the rake task.
#HISTORY: Full history available onsite.
#Running on an invalid date will not submit any records. No duplicates will be made.

class PreciousForwardScraper
  def initialize
    @new_entries = Array.new
  end
  
  def scrape_on(date)
    #Gold Forward (just gets the whole year since libor rates have a delay)
    url = "http://www.lbma.org.uk/pages/index.cfm?page_id=55&title=gold_forwards&show=" + date.year.to_s
    doc = Nokogiri::HTML(open(url))
    table = doc.css('table.pricing_detail_small')
    table.css('thead').remove
    table.css('tr').to_a.each do |row|
      row_data = Array.new
      row.css('td').each_with_index do |cell,i|
        row_data[i] = cell.content
      end
      next if row_data[0] == ""
      #since website uses two digit years which confuse ruby, let's sub in our
      #four digit years instead
      row_data[0] = row_data[0][0,row_data[0].length-2] + date.year.to_s
      #check if this is the correct date
      begin
        next if Date.parse(row_data[0]) != date
      rescue
        next
      end
      #turn blank entries and words like "day off for christmas" into nil cells
      row_data.each_index do |j|
        next if j == 0
        temp = /[\-0-9.]+/.match(row_data[j]).to_s
        row_data[j] = temp != "" ? temp.to_f : nil
      end
      if !row_data[1,5].compact.empty? or !row_data[11,15].compact.empty?
        entry = Entry.new
        entry.metal = Metal.where(:name => 'Gold').first
        entry.dataset_name = 'Forward Offered Rates'
        entry.date = date
        entry.gofo1 = row_data[1]
        entry.gofo2 = row_data[2]
        entry.gofo3 = row_data[3]
        entry.gofo6 = row_data[4]
        entry.gofo12 = row_data[5]
        entry.libor1 = row_data[11]
        entry.libor2 = row_data[12]
        entry.libor3 = row_data[13]
        entry.libor6 = row_data[14]
        entry.libor12 = row_data[15]
        entry.save
        @new_entries << entry
      end
      break
    end
    
    #Silver forwards (again, just gets the whole year)
    url = "http://www.lbma.org.uk/pages/index.cfm?page_id=56&title=silver_forwards&show=" + date.year.to_s
    doc = Nokogiri::HTML(open(url))
    table = doc.css('table.pricing_detail')
    table.css('thead').remove
    table.css('tr').to_a.each do |row|
      row_data = Array.new
      row.css('td').each_with_index do |cell,i|
        row_data[i] = cell.content
      end
      next if row_data[0] == ""
      #since website uses two digit years which confuse ruby, let's sub in our
      #four digit years instead
      row_data[0] = row_data[0][0,row_data[0].length-2] + date.year.to_s
      #check if this is the correct date
      begin
        next if Date.parse(row_data[0]) != date
      rescue
        next
      end
      #turn blank entries and words like "day off for christmas" into nil cells
      row_data.each_index do |j|
        next if j == 0
        temp = /[\-0-9.]+/.match(row_data[j]).to_s
        row_data[j] = temp != "" ? temp.to_f : nil
      end
      if !row_data[1,10].compact.empty?
        entry = Entry.new
        entry.metal = Metal.where(:name => 'Silver').first
        entry.dataset_name = 'Indicative Forward Mid Rates'
        entry.date = date
        entry.gofo1 = row_data[1]
        entry.gofo2 = row_data[2]
        entry.gofo3 = row_data[3]
        entry.gofo6 = row_data[4]
        entry.gofo12 = row_data[5]
        entry.libor1 = row_data[6]
        entry.libor2 = row_data[7]
        entry.libor3 = row_data[8]
        entry.libor6 = row_data[9]
        entry.libor12 = row_data[10]
        entry.save
        @new_entries << entry
      end
      break
    end
  end
  
  def scrape_history
    #Gold Forwards
    
    #First prepare Typhoeus
    hydra = Typhoeus::Hydra.new
    requests = Array.new
    1989.upto(Date.today.year) do |year|
      index = year-1989
      url = "http://www.lbma.org.uk/pages/index.cfm?page_id=55&title=gold_forwards&show=" + year.to_s
      requests[index] = Typhoeus::Request.new(url)
      hydra.queue(requests[index])
    end
    puts "Starting hydra"
    hydra.run
    puts "Hydra finished"
    
    the_metal = Metal.where(:name => 'Gold').first
    1989.upto(Date.today.year) do |year|
      index = year - 1989
      doc = Nokogiri::HTML(requests[index].response.body)
      table = doc.css('table.pricing_detail_small')
      table.css('thead').remove
      table.css('tr').to_a.each do |row|
        row_data = Array.new
        row.css('td').each_with_index do |cell,i|
          row_data[i] = cell.content
        end
        next if row_data[0] == ""
        #since website uses two digit years which confuse ruby, let's sub in our
        #four digit years instead
        row_data[0] = row_data[0][0,row_data[0].length-2] + year.to_s
        #turn blank entries and words like "day off for christmas" into nil cells
        row_data.each_index do |j|
          next if j == 0
          temp = /[\-0-9.]+/.match(row_data[j]).to_s
          row_data[j] = temp != "" ? temp.to_f : nil
        end
        entry = Entry.new
        entry.metal = the_metal
        entry.dataset_name = 'Forward Offered Rates'
        entry.date = Date.parse(row_data[0])
        if year == 1989
          if !row_data[1,4].compact.empty? or !row_data[9,12].compact.empty?
            entry.gofo1 = row_data[1]
            entry.gofo3 = row_data[2]
            entry.gofo6 = row_data[3]
            entry.gofo12 = row_data[4]
            entry.libor1 = row_data[9]
            entry.libor3 = row_data[10]
            entry.libor6 = row_data[11]
            entry.libor12 = row_data[12]
            entry.save
            @new_entries << entry
          end
        else
          if !row_data[1,5].compact.empty? or !row_data[11,15].compact.empty?
            entry.gofo1 = row_data[1]
            entry.gofo2 = row_data[2]
            entry.gofo3 = row_data[3]
            entry.gofo6 = row_data[4]
            entry.gofo12 = row_data[5]
            entry.libor1 = row_data[11]
            entry.libor2 = row_data[12]
            entry.libor3 = row_data[13]
            entry.libor6 = row_data[14]
            entry.libor12 = row_data[15]
            entry.save
            @new_entries << entry
          end
        end
      end
    end
    
    #Silver forwards
    
    #First prepare Typhoeus
    hydra = Typhoeus::Hydra.new
    requests = Array.new
    2006.upto(Date.today.year) do |year|
      index = year-2006
      url = "http://www.lbma.org.uk/pages/index.cfm?page_id=56&title=silver_forwards&show=" + year.to_s
      requests[index] = Typhoeus::Request.new(url)
      hydra.queue(requests[index])
    end
    puts "Starting hydra"
    hydra.run
    puts "Hydra finished"
    
    the_metal = Metal.where(:name => 'Silver').first
    2006.upto(Date.today.year) do |year|
      index = year-2006
      doc = Nokogiri::HTML(requests[index].response.body)
      table = doc.css('table.pricing_detail')
      table.css('thead').remove
      table.css('tr').to_a.each do |row|
        row_data = Array.new
        row.css('td').each_with_index do |cell,i|
          row_data[i] = cell.content
        end
        next if row_data[0] == ""
        #since website uses two digit years which confuse ruby, let's sub in our
        #four digit years instead
        row_data[0] = row_data[0][0,row_data[0].length-2] + year.to_s
        #turn blank entries and words like "day off for christmas" into nil cells
        row_data.each_index do |j|
          next if j == 0
          temp = /[\-0-9.]+/.match(row_data[j]).to_s
          row_data[j] = temp != "" ? temp.to_f : nil
        end
        if !row_data[1,10].compact.empty?
          entry = Entry.new
          entry.metal = the_metal
          entry.dataset_name = 'Indicative Forward Mid Rates'
          entry.date = Date.parse(row_data[0])
          entry.gofo1 = row_data[1]
          entry.gofo2 = row_data[2]
          entry.gofo3 = row_data[3]
          entry.gofo6 = row_data[4]
          entry.gofo12 = row_data[5]
          entry.libor1 = row_data[6]
          entry.libor2 = row_data[7]
          entry.libor3 = row_data[8]
          entry.libor6 = row_data[9]
          entry.libor12 = row_data[10]
          entry.save
          @new_entries << entry
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
    entry_attr_accessor :metal, :dataset_name, :date, :gofo1, :gofo2, :gofo3, :gofo6, :gofo12, :libor1, :libor2, :libor3, :libor6, :libor12
    
    def to_s
      @record.select{|k| [:metal,:dataset_name, :date].include? k}.to_s
    end
    
    def submit(insert = false)
      if !insert
        @record[:metal].metal_datasets.where(:name => @record[:dataset_name]).first.first_or_create_data_row(:date => @record[:date]).update_attributes(@record.select{|k| ![:metal,:dataset_name,:date].include? k})
      else
        @record[:metal].metal_datasets.where(:name => @record[:dataset_name]).first.create_data_row(:date => @record[:date]).update_attributes(@record.select{|k| ![:metal,:dataset_name,:date].include? k})
      end
      puts 'Entry ' + to_s + ' submitted'
    end
  end
end