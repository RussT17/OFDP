class StockOptionsController < ApplicationController
  def show
    the_option = StockOption.find(params[:id])
    @rows = the_option.stock_option_data_rows
    @title = the_option.symbol
  end

  def index
    if params[:all]
      @contents = StockOption.all
    else
      @contents = StockOption.order('symbol').page(params[:page])
    end
  end
end