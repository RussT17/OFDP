class StockOptionsController < ApplicationController
  def show
  end

  def index
    @contents = StockOption.order('symbol').page(params[:page])
  end
end