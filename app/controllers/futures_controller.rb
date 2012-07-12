class FuturesController < ApplicationController
  def show
    @selected = Hash.new
    
    #create an array of the names of the sorting fields
    @fields = ['ticker','month','year','exchange']
    
    #keep track of which choices the user made
    @fields.each {|f| @selected[f] = params[f] if params[f] != 'none'}
    
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
  
  def index
    @contents = FuturesContent.order('id').page(params[:page])
  end
end
