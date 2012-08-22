class FuturesController < ApplicationController
  def show
    @the_future = Future.find(params[:id])
  end
  
  def index
    if params[:all]
      @contents = Future.joins(:asset).where("assets.name is not null")
    else
      @contents = Future.joins(:asset).where("assets.name is not null").order("assets.symbol,year,month").page(params[:page])
    end
  end
end
