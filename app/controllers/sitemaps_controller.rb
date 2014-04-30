##
# Machinery for validating sitemaps
class SitemapsController < ApplicationController
  ##
  # [GET] Landing page
  def new
    @sitemap = Sitemap.new
  end
  
  ##
  # [GET/POST] Validate a sitemap given by a URL or by POSTed content
  def validate
    @sitemap = Sitemap.new sitemap_params
    
    if !@sitemap.sitemap?
      flash[:alert] = "Invalid sitemap"
      render 'new'
    else
      @sitemap.valid?
    end
  end
  
  ##
  # [GET] Validate a sitemap resource against sitemap and resourcesync metadata 
  def validate_resource
    url = SitemapUrl.new resource_params
    
    errors = ActiveModel::Errors.new url
    
    if url.response.status == 200

      if url.response_last_modified && url.lastmod

        last_modified_date = DateTime.parse(url.lastmod)

        if url.lastmod.length <= 10
          # yyyy-mm-dd granularity
          last_modified_date += 1.day
        end

        if url.response_last_modified && url.lastmod && url.response_last_modified > last_modified_date
          errors.add "last modified" "expected #{url.lastmod} to be later than #{url.response_last_modified}"
        end
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
  
  def resource_params
    params.require(:url)
  end
end
