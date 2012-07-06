class HomeController < ApplicationController
  def index
    redirect_to :controller => 'futures'
  end
end
