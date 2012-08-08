require "nokogiri"
require "open-uri"
require "typhoeus"
require 'spreadsheet'
require "date"

#SCRAPE: No date selection available, though the date of the currently posted settlement prices is given on site
#HISTORY: Excel documents with all the history of the current year except for the current month
#Running on a weekend or holiday will not cause problems or duplications. No duplicates will be made in any case.

class NonpreciousScraper
  def initialize
    @new_entries = Array.new
  end
  
  def scrape
    #no date necessary, given on website
    
    #First get Typhoeus ready
    hydra = Typhoeus::Hydra.new
    requests = Array.new
    Metal.where(:source => "lme").all.each_with_index do |metal,index|
      url = "http://www.lme.com" + metal.data_path
      requests[index] = Typhoeus::Request.new(url)
      hydra.queue(requests[index])
    end
    puts "Starting hydra"
    hydra.run
    puts "Hydra finished"
    
    Metal.where(:source => "lme").all.each_with_index do |metal,index|
      puts metal.name.downcase
      doc = Nokogiri::HTML(requests[index].response.body)
      begin
        date = Date.parse(/for/.match(doc.css("b.primaryHeader").first.content.gsub(/\s/,"")).post_match)
      rescue
        next
      end
      table = doc.css("table table table").first
      if ["aluminium","copper","zinc","lead","nickel","aluminium alloy","nasaac"].include? metal.name.downcase
        row_data = Array.new
        table.css("td").to_a.each_with_index do |cell,i|
          temp = /[\-0-9.\,]+/.match(cell.content.gsub(/,/,"")).to_s.strip
          row_data[i] = temp != "" ? temp.to_f : nil
        end
        [['Cash',6,7],['3-Months',10,11],['December 1',14,15],['December 2',18,19],['December 3',22,23]].each do |arr|
          if !row_data[arr[1]].nil? and !row_data[arr[2]].nil?
            entry = Entry.new
            entry.metal = metal
            entry.dataset_name = arr[0]
            entry.date = date
            entry.buyer = row_data[arr[1]]
            entry.seller = row_data[arr[2]]
            entry.save
            @new_entries << entry
          end
        end
      else
        row_data = Array.new
        table.css("td").to_a.each_with_index do |cell,i|
          temp = /[\-0-9.\,]+/.match(cell.content.gsub(/,/,"")).to_s.strip
          row_data[i] = temp != "" ? temp.to_f : nil
        end
        [['Cash',14,20],['3-Months',26,32],['15-Months',38,44]].each do |arr|
          if !row_data[arr[1]].nil? and !row_data[arr[2]].nil?
            entry = Entry.new
            entry.metal = metal
            entry.dataset_name = arr[0]
            entry.date = date
            entry.buyer = row_data[arr[1]]
            entry.seller = row_data[arr[2]]
            entry.save
            @new_entries << entry
          end
        end
      end
    end
  end
  
  def scrape_history
    doc = Nokogiri::HTML(open("http://www.lme.com/dataprices_historical.asp"))
    links = doc.css('a.greenSmallBold')
    links.to_a.each do |link|
      if /Price/.match(link['onclick'])
        path = link['href']
        url = "http://www.lme.com" + path
        book = nil
        open(url) do |f|
          book = Spreadsheet.open f
        end
        Metal.where("source = 'lme'").each do |metal|
          puts metal.name
          sheet_name = case metal.name
          when "NASAAC"
            "NA Alloy"
          when "Aluminium"
            "Primary Aluminium"
          when "Steel Billet"
            "Global Steel"
          else
            metal.name
          end
          sheet = book.worksheet sheet_name
          sheet.each 8 do |row|
            if row[1].class.name == 'Date'
              date = row[1]
              metal.metal_datasets.each_with_index do |dataset,i|
                buyer = row[3*i + 2]
                seller = row[3*i + 3]
                entry = Entry.new
                entry.metal = metal
                entry.dataset_name = dataset.name
                entry.date = date
                entry.buyer = buyer
                entry.seller = seller
                entry.save
                @new_entries << entry
              end
            end
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
  
  class Entry < DataEntry
    entry_attr_accessor :metal, :dataset_name, :date, :buyer, :seller
    
    def to_s
      @record.select{|k| [:metal,:dataset_name, :date].include? k}.to_s
    end
    
    def submit(insert = false)
      if !insert
        @record[:metal].metal_datasets.where(:name => @record[:dataset_name]).first.first_or_create_data_row(:date => @record[:date]).update_attributes(:buyer => @record[:buyer], :seller => @record[:seller])
      else
        @record[:metal].metal_datasets.where(:name => @record[:dataset_name]).first.create_data_row(:date => @record[:date]).update_attributes(:buyer => @record[:buyer], :seller => @record[:seller])
      end
      puts 'Entry ' + to_s + ' submitted'
    end
  end
end