class MetalPricesController < ApplicationController
  def show
    @the_dataset = MetalDataset.find(params[:id])
  end
  
  def index
    if params[:all]
      @contents = MetalDataset.all
    else
      @contents = MetalDataset.joins(:metal).order("metals.name,name").page(params[:page])
    end
  end
end
