class FuturesController < ApplicationController
  def show
    @the_future = Future.find(params[:id])
    @rows = @the_future.future_data_rows
  end
  
  def index
    @contents = Future.joins(:asset).where("assets.name is not null").order("assets.symbol,year,month").page(params[:page])
  end
end
