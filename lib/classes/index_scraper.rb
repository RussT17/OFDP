require 'nokogiri'
require 'open-uri'
require 'date'

class IndexScraper
  def initialize
    @new_entries = Array.new
  end
  
  def scrape_dryships
    doc = Nokogiri::HTML(open('http://www.dryships.com/pages/report.asp'))
    meta_info = doc.dup.css('p[align="center"]')[0]
    meta_info.css('strong').remove
    date = Date.parse(meta_info.content)
    data_array = doc.css('html>body>div>table>tbody>tr:nth-child(3)>td:nth-child(2)>table>tbody>tr>td strong').to_a
    
    bdi = Entry.new
    bdi.index = Index.where(name: 'Baltic Dry Index').first_or_create
    bdi.date = date
    bdi.value = /[[:digit:]]+/.match(data_array[5].content)[0].to_i
    bdi.save
    @new_entries << bdi

    bci = Entry.new
    bci.index = Index.where(name: 'Baltic Cape Index').first_or_create
    bci.date = date
    bci.value = data_array[18].content.strip.to_i
    bci.save
    @new_entries << bci
    
    bpi = Entry.new
    bpi.index = Index.where(name: 'Baltic Panamax Index').first_or_create
    bpi.date = date
    bpi.value = data_array[22].content.strip.to_i
    bpi.save
    @new_entries << bpi
    
    bsi = Entry.new
    bsi.index = Index.where(name: 'Baltic Supramax Index').first_or_create
    bsi.date = date
    bsi.value = data_array[26].content.strip.to_i
    bsi.save
    @new_entries << bsi
  end
  
  def add_to_database
    @new_entries.delete_if do |entry|
      entry.submit
      true
    end
  end
  
  class Entry < DataEntry
    entry_attr_accessor :index, :date, :value
    
    def to_s
      @record.select{|k| [:index,:date].include? k}.to_s
    end
    
    def submit
      @record[:index].index_data_rows.where(date: @record[:date]).first_or_create.update_attributes(value: @record[:value])
      puts "Entry " + to_s + " submitted"
    end
  end
end