class FuturesController < ApplicationController
  def show
    @the_future = Future.find(params[:id])
  end
  
  def index
    futures_to_show = Future.joins(:asset).where("assets.name is not null").order("assets.symbol,year,month").to_a.select {|future| future.valid?}
    @contents = Kaminari.paginate_array(futures_to_show).page(params[:page])
  end
end
