class FuturesController < ApplicationController
  def index
    #keep track of which choices the user made
    @exchange_selected = params[:exchange] if params[:exchange] != 'none'
    @ticker_selected = params[:ticker] if params[:ticker] != 'none'
    @month_selected = params[:month] if params[:month] != 'none'
    @year_selected = params[:year] if params[:year] != 'none'
    
    #narrow down the data to tailor the user's choices
    selected_data = FuturesDataRow
    selected_data = selected_data.where("exchange = ?",@exchange_selected) if !@exchange_selected.nil?
    selected_data = selected_data.where("ticker = ?",@ticker_selected) if !@ticker_selected.nil?
    selected_data = selected_data.where("month = ?",@month_selected) if !@month_selected.nil?
    selected_data = selected_data.where("year = ?",@year_selected.to_i) if !@year_selected.nil?
    
    #determine further options to display to the user, display all if the option is already selected
    temp_selected_data = FuturesDataRow
    temp_selected_data = temp_selected_data.where("ticker = ?",@ticker_selected) if !@ticker_selected.nil?
    temp_selected_data = temp_selected_data.where("month = ?",@month_selected) if !@month_selected.nil?
    temp_selected_data = temp_selected_data.where("year = ?",@year_selected.to_i) if !@year_selected.nil?
    @exchange_options = temp_selected_data.group(:exchange).map {|row| row.exchange}
    temp_selected_data = FuturesDataRow
    temp_selected_data = temp_selected_data.where("exchange = ?",@exchange_selected) if !@exchange_selected.nil?
    temp_selected_data = temp_selected_data.where("month = ?",@month_selected) if !@month_selected.nil?
    temp_selected_data = temp_selected_data.where("year = ?",@year_selected.to_i) if !@year_selected.nil?
    @ticker_options = temp_selected_data.group(:ticker).map {|row| row.ticker}
    temp_selected_data = FuturesDataRow
    temp_selected_data = temp_selected_data.where("ticker = ?",@ticker_selected) if !@ticker_selected.nil?
    temp_selected_data = temp_selected_data.where("exchange = ?",@exchange_selected) if !@exchange_selected.nil?
    temp_selected_data = temp_selected_data.where("year = ?",@year_selected.to_i) if !@year_selected.nil?
    @month_options = temp_selected_data.group(:month).map {|row| row.month}
    temp_selected_data = FuturesDataRow
    temp_selected_data = temp_selected_data.where("ticker = ?",@ticker_selected) if !@ticker_selected.nil?
    temp_selected_data = temp_selected_data.where("month = ?",@month_selected) if !@month_selected.nil?
    temp_selected_data = temp_selected_data.where("exchange = ?",@exchange_selected.to_i) if !@exchange_selected.nil?
    @year_options = temp_selected_data.group(:year).map {|row| row.year.to_s}
    
    #display data if all four selections are made
    @data = selected_data if @exchange_selected and @ticker_selected and @month_selected and @year_selected
  end
end
