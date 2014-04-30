##
# A Sitemap urlset entry
class SitemapUrl < OpenStruct
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  
  ##
  # Extract a SitemapUrl from an XML fragment
  def self.from_fragment s
    h = {}
    s.children.each do |n| 
      if n.inner_text.blank? && n.attributes.any?
        h[n.name] ||= []
        h[n.name] << Hash[n.attributes.map { |k,v| [k,v.to_s] }]
      else
        h[n.name] = n.inner_text
      end
    end
    h['md'] &&= h['md'].first
    self.new({doc: s}.merge(h))
  end

  ##
  # Retrieve the content at the given location
  def response
    @response ||= Faraday.get loc
  end
  
  ##
  # Get the advertised content-length, or calculate it from the response body 
  # @return [Integer]
  def response_length
    (response.headers['content-length'] if response.headers['content-length']) || response.body.length
  end
  
  ##
  # Parse the Last-Modified header from the response
  # @return [DateTime]
  def response_last_modified
    DateTime.parse(response.headers['Last-Modified']) if response.headers['Last-Modified']
  end
  
  ##
  # Get the resourcesync ln elements
  def lns
    ln || []
  end
  
  ##
  # Group the resourcesync lns by their rel attribute
  def lns_by_rel
    lns.group_by { |x| x['rel'] }
  end
  
  def persisted?
    false
  end
  
  def to_partial_path
    "sitemaps/#{self.class.to_s.underscore}"
  end
  
end
