class FuturesController < ApplicationController
  def show
    @the_future = Future.find(params[:id])
  end
  
  def index
    @contents = Future.joins(:asset).where("assets.name is not null and is_valid is true").order("assets.symbol,year,month").page(params[:page])
  end
end
