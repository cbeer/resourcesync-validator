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
  
  def validate_resource
    params.require(:url)
    url = SitemapUrl.new params[:url]
    
    errors = ActiveModel::Errors.new url
    
    if url.response.status == 200
    
      last_modified_date = DateTime.parse(url.lastmod)
      
      if url.lastmod.length <= 10
        # yyyy-mm-dd granularity
        last_modified_date += 1.day
      end
      
      if url.response_last_modified && url.lastmod && url.response_last_modified > last_modified_date
        errors.add "last modified" "expected #{url.lastmod} to be later than #{url.response_last_modified}"
      end
      
      if url.md && url.md[:length] && url.response_length != url.md[:length]
        errors.add "length", "expected #{url.md[:length]}, but got #{url.response_length}"
      end
      
    else  
      errors.add "http status", url.response.status.to_s unless url.md and url.md[:change] == 'deleted'
    end
    
    if errors.empty?
      render text: 'ok'
    else
      error_status = url.response.status
      
      if error_status == 200
        error_status = 417
      end

      render text: errors.full_messages.join("; \n"), status: error_status
    end
  end
  
  private
  def sitemap_params
    params.require(:sitemap)
  end
end
