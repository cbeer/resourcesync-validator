class SitemapIndexUrl < SitemapUrl
  ##
  # Load this sitemap index url as a sitemap
  def sitemap
    Sitemap.new url: loc
  end
end
