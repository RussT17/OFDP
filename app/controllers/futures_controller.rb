class FuturesController < ApplicationController
  def index
    @selected = Hash.new
    @all_options = Hash.new
    @valid_options = Hash.new
    
    #create an array of the names of the sorting fields
    @fields = ['ticker','month','year','exchange']
    
    #determine all possible options for each field, whether or not they will return data (should be done only when new data is added and stored in database)
    @fields.each {|f| @all_options[f] = FuturesDataRow.uniq.pluck(f)}
    
    #keep track of which choices the user made
    @fields.each {|f| @selected[f] = params[f] if params[f] != 'none'}
    
    #determine valid options to display to the user, if something is selected
    if @fields.map {|f| @selected[f].nil?} != [true,true,true,true]
      @fields.each do |f|
        temp_selected_data = FuturesDataRow
        (@fields - [f]).each do |g|
          if g != 'year'
            temp_selected_data = temp_selected_data.where("#{g} = ?", @selected[g]) if !@selected[g].nil?
          else
            temp_selected_data = temp_selected_data.where("#{g} = ?", @selected[g].to_i) if !@selected[g].nil?
          end
        end
        @valid_options[f] = temp_selected_data.uniq.pluck(f)
      end
    else
      @valid_options = @all_options
    end

    #display data if all four selections are made
    if @fields.map {|f| @selected[f].nil?} == [false,false,false,false]
      selected_data = FuturesDataRow
      @fields.each {|f| selected_data = selected_data.where("#{f} = ?", @selected[f]) if !@selected[f].nil?}
      @data = selected_data
      @name = '(' + @selected['ticker'] + @selected['month'] + @selected['year'].to_s + ')'
      if !TickerSymbol.where("symbol = '#{@selected['ticker']}'").where("exchange = '#{@selected['exchange']}'").length.zero?
      @name = TickerSymbol.where("symbol = '#{@selected['ticker']}'").where("exchange = '#{@selected['exchange']}'").first.name + ' ' +
        MonthCode.where("code = '#{@selected['month']}'").first.month.capitalize + ' ' + @selected['year'].to_s + ' ' << @name
      end
    end
  end
  
  def table_of_contents
    contents = FuturesDataRow.select('ticker,month,year,exchange').uniq.map {|record| {'ticker' => record.ticker, 'month' => record.month, 'year' => record.year, 'exchange' => record.exchange}}
    contents.delete_if {|c| TickerSymbol.where("symbol = '#{c['ticker']}'").where("exchange = '#{c['exchange']}'").length == 0}
 
    contents.sort! do |a,b|
      comp = (a['ticker'] <=> b['ticker'])
      if comp.zero?
        comp = (a['exchange'] <=> b['exchange'])
        if comp.zero?
          comp = (a['year'] <=> b['year'])
          if comp.zero?
            comp = (a['month'] <=> b['month'])
          else
            comp
          end
        else
          comp
        end
      else
        comp
      end
    end

    #generate urls for display
    @urls = contents.map {|c| futures_url + '?ticker=' + c['ticker'] + '&month=' + c['month'] + '&year=' + c['year'].to_s + '&exchange=' + c['exchange']}
    
    #generate ticker for display
    @tickers = contents.map {|c| c['ticker'] + c['month'] + c['year'].to_s}
    
    #generate name for display
    @names = contents.map {|c| TickerSymbol.where("symbol = '#{c['ticker']}'").where("exchange = '#{c['exchange']}'").first.name + ' ' +
      MonthCode.where("code = '#{c['month']}'").first.month.capitalize + ' ' + c['year'].to_s + ' ' + '(' + c['ticker'] + c['month'] + c['year'].to_s + ')'}
      
    #generate description for display
    @descriptions = Array.new
    contents.each_index {|i| @descriptions[i] = 'Future Contract: ' + (/\s\(/).match(@names[i]).pre_match + ' Ticker: ' + @tickers[i] + ' Exchange: ' + contents[i]['exchange']}
  end
end
