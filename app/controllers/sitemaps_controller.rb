class SitemapsController < ApplicationController
  def new
    @sitemap = Sitemap.new
  end
  
  def validate
    @sitemap = Sitemap.new sitemap_params
    
    if !@sitemap.sitemap?
      flash[:alert] = "Invalid sitemap"
      render 'new'
    else
      @sitemap.valid?
    end
  end
  
  private
  def sitemap_params
    params.require(:sitemap)
  end
end
