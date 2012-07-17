class CfcsController < ApplicationController
  #Continuous Futures Contracts Controller
  def show
    @the_cfc = Cfc.find(params[:id])
  end
  
  def index
    @contents = Cfc.joins(:asset).where("assets.name is not null").order("assets.symbol,depth").page(params[:page])
  end
end