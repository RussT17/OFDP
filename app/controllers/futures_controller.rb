class FuturesController < ApplicationController
  def index
    @selected = Hash.new
    @all_options = Hash.new
    @valid_options = Hash.new
    
    #create an array of the names of the sorting fields
    @fields = ['ticker','month','year','exchange']
    
    #get all the possible options for each field from the database
    @fields.each {|f| @all_options[f] = FuturesChoice.where("type = ?",f).pluck(:choice)}
    
    #keep track of which choices the user made
    @fields.each {|f| @selected[f] = params[f] if params[f] != 'none'}
    
    #determine valid options to display to the user, if something is selected
    if @fields.map {|f| @selected[f].nil?} != [true,true,true,true]
      @fields.each do |f|
        temp_selected_data = FuturesDataRow
        (@fields - [f]).each do |g|
          temp_selected_data = temp_selected_data.where("#{g} = ?", @selected[g]) if !@selected[g].nil?
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
      @name = '(' + @selected['ticker'] + @selected['month'] + @selected['year'] + ')'
      if !TickerSymbol.where("symbol = '#{@selected['ticker']}'").where("exchange = '#{@selected['exchange']}'").length.zero?
      @name = TickerSymbol.where("symbol = '#{@selected['ticker']}'").where("exchange = '#{@selected['exchange']}'").first.name + ' ' +
        Ofdp::Application::MONTH_NAMES[@selected['month']] + ' ' + @selected['year'] + ' ' << @name
      end
    end
  end
  
  def table_of_contents
    @contents = FuturesContent.order('id').page(params[:page])
  end
end
