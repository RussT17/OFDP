require 'nokogiri'
require 'date'
require 'open-uri'

#This file requires a codelist in the code folder, these little codes form a part of the url. different urls are
#available for each week. for the past half year the codes/urls have been pretty static, if a coming week has different
#available urls, an entry will have to be added to the codelist.

#SCRAPE: scrapes the most recent available date of data

#SCRAPE HISTORY: Over five years of data available.

class CotScraper
  def initialize
    @new_entries = Array.new
  end
  
  def scrape_newest_before(input_date)
    string = String.new
    File.open(Dir[Rails.root.join "lib/classes/codes/cotcodes"][0],'r') do |f|
      f.each do |row|
        string << row
      end
    end
    linkhash = eval(string)
    
    index_url = 'http://www.cftc.gov/MarketReports/CommitmentsofTraders/HistoricalViewable/index.htm'
    doc = Nokogiri::HTML(open(index_url))
    doc.css('center').remove
    dates = doc.css('ul.text table a').map{|link| /cot/.match(link['href']).post_match}.sort_by{|date| Date.strptime(date,'%m%d%y')}
    the_date = dates.reject{|date| Date.strptime(date,'%m%d%y') > input_date}.max_by{|date| Date.strptime(date,'%m%d%y')}

    last_links = []
    dates.each do |date|
      links = linkhash[date]
      links = last_links if links.nil?
      if date == the_date
        links.each do |link|
          url = 'http://www.cftc.gov/files/dea/cotarchives/20' + date[4..5] + '/futures/' + link + date + '.htm'
          text = Nokogiri::HTML(open(url)).css('pre')[0].content
          textIO = StringIO.new(text)
          if !['ag_sf','petroleum_sf','nat_gas_sf','electricity_sf','other_sf'].include? link
            lineprev = ''
            entry = Entry.new #just to avoid ruby error
            textIO.each do |line|
              match = /AS\sOF/.match(line)
              if match
                entry = Entry.new
                entry.legacy = true
                code_match = /Code/.match(lineprev)
                if code_match
                  entry.name = code_match.pre_match.strip
                else
                  entry.name = lineprev.strip
                end
                entry.date = Date.strptime(match.post_match.sub('|','').strip, '%m/%d/%y')
              end
              if /COMMITMENTS/.match(line)
                entry.desc = /OPEN/.match(lineprev).pre_match.gsub(/[():]/,'').strip
              end 
              if /COMMITMENTS/.match(lineprev)
                entry.data = line.strip
                entry.save
                @new_entries << entry
              end
              lineprev = line
            end
          else
            lineprev = ''
            textIO.each do |line|
              match = /as\sof/.match(line)
              if match
                entry = Entry.new
                entry.legacy = false
                entry.date = Date.parse(match.post_match.strip)
              end
              match = /CFTC/.match(line)
              if match
                match = /\([^(]*:/.match(lineprev)
                entry.name = match.pre_match.strip
                entry.desc = match[0].gsub(/[():]/,'').strip
              end
              match = /:\sPositions/.match(lineprev)
              if match
                entry.data = line.gsub(/:/,'').strip
                entry.save
                @new_entries << entry
              end
              lineprev = line
            end
          end
        end
      end
      last_links = links
    end
    nil
  end
  
  def scrape_history
    string = String.new
    File.open(Dir[Rails.root.join "lib/classes/codes/cotcodes"][0],'r') do |f|
      f.each do |row|
        string << row
      end
    end

    linkhash = eval(string)

    index_url = 'http://www.cftc.gov/MarketReports/CommitmentsofTraders/HistoricalViewable/index.htm'

    doc = Nokogiri::HTML(open(index_url))

    doc.css('center').remove
    dates = doc.css('ul.text table a').map{|link| /cot/.match(link['href']).post_match}.sort_by{|date| Date.strptime(date,'%m%d%y')}

    last_links = []
    dates.each do |date|
      links = linkhash[date]
      links = last_links if links.nil?
      links.each do |link|
        url = 'http://www.cftc.gov/files/dea/cotarchives/20' + date[4..5] + '/futures/' + link + date + '.htm'
        text = Nokogiri::HTML(open(url)).css('pre')[0].content
        textIO = StringIO.new(text)
        if !['ag_sf','petroleum_sf','nat_gas_sf','electricity_sf','other_sf'].include? link
          lineprev = ''
          entry = Entry.new #just to avoid ruby error
          textIO.each do |line|
            match = /AS\sOF/.match(line)
            if match
              entry = Entry.new
              entry.legacy = true
              code_match = /Code/.match(lineprev)
              if code_match
                entry.name = code_match.pre_match.strip
              else
                entry.name = lineprev.strip
              end
              entry.date = Date.strptime(match.post_match.sub('|','').strip, '%m/%d/%y')
            end
            if /COMMITMENTS/.match(line)
              entry.desc = /OPEN/.match(lineprev).pre_match.gsub(/[():]/,'').strip
            end 
            if /COMMITMENTS/.match(lineprev)
              entry.data = line.strip
              entry.save
              @new_entries << entry
            end
            lineprev = line
          end
        else
          lineprev = ''
          textIO.each do |line|
            match = /as\sof/.match(line)
            if match
              entry = Entry.new
              entry.legacy = false
              entry.date = Date.parse(match.post_match.strip)
            end
            match = /CFTC/.match(line)
            if match
              match = /\([^(]*:/.match(lineprev)
              entry.name = match.pre_match.strip
              entry.desc = match[0].gsub(/[():]/,'').strip
            end
            match = /:\sPositions/.match(lineprev)
            if match
              entry.data = line.gsub(/:/,'').strip
              entry.save
              @new_entries << entry
            end
            lineprev = line
          end
        end
      end
      last_links = links
    end
    nil
  end
  
  def add_to_database
    @new_entries.delete_if do |entry|
      entry.submit
      true
    end
  end
  
  private
  
  class Entry < DataEntry
    entry_attr_accessor :name, :desc, :legacy, :date, :data
    
    def to_s
      @record.select{|k| [:name,:legacy,:date].include? k}.to_s
    end
    
    def submit
      @cot = Cot.where(name: @record[:name], legacy: @record[:legacy]).first_or_create
      @cot.update_attributes(desc: @record[:desc])
      @cot.cot_data_rows.where(date: @record[:date]).first_or_create.update_attributes(data: @record[:data])
    end
  end
end