class MetalPricesController < ApplicationController
  def show
    @the_dataset = MetalDataset.find(params[:id])
  end
  
  def index
    @contents = MetalDataset.joins(:metal).order("metals.name,name").page(params[:page])
  end
end
