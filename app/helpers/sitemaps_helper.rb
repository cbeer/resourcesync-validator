module SitemapsHelper
  ##
  # Is the given capability in the list of valid ResourceSync capabilities?
  def is_valid_capability? capability
    Sitemap.valid_capabilities.include? capability
  end
end
