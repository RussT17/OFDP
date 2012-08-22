class IndicesController < ApplicationController
  def show
    @the_index = Index.find(params[:id])
    @rows = @the_index.index_data_rows.order('date DESC')
  end
  
  def index
    if params[:all]
      @contents = Index.all
    else
      @contents = Index.order(:name).page(params[:page])
    end
  end
end
