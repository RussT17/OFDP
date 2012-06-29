class FuturesController < ApplicationController
  def index
    @selected = Hash.new
    @all_options = Hash.new
    @valid_options = Hash.new
    
    #create an array of the names of the sorting fields
    @fields = ['ticker','month','year','exchange']
    
    #determine all possible options for each field, whether or not they will return data
    @fields.each {|f| @all_options[f] = FuturesDataRow.group(f).map {|row| row.send(f).to_s}}
    
    #keep track of which choices the user made
    @fields.each {|f| @selected[f] = params[f] if params[f] != 'none'}
    
    #narrow down the data to tailor the user's choices
    selected_data = FuturesDataRow
    @fields.each {|f| selected_data = selected_data.where("#{f} = ?", @selected[f]) if !@selected[f].nil?}
    
    #determine valid options to display to the user, display all if the option is already selected
    @fields.each do |f|
      temp_selected_data = FuturesDataRow
      (@fields - [f]).each do |g|
        if g != 'year'
          temp_selected_data = temp_selected_data.where("#{g} = ?", @selected[g]) if !@selected[g].nil?
        else
          temp_selected_data = temp_selected_data.where("#{g} = ?", @selected[g].to_i) if !@selected[g].nil?
        end
      end
      @valid_options[f] = temp_selected_data.group(f).map {|row| row.send(f).to_s}
    end
    
    #if a field has only one option, select it
    @fields.each {|f| @selected[f] = @valid_options[f][0] if @valid_options[f].length == 1}
    
    #display data if all four selections are made
    @data = selected_data if @fields.map {|f| @selected[f].nil?} == [false,false,false,false]
  end
end
