class SitemapUrl < OpenStruct
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  
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
  
  def persisted?
    false
  end
  
  def response
    @response ||= Faraday.get loc
  end
  
  def response_length
    response.headers['content-length']
  end
  
  def response_last_modified
    DateTime.parse(response.headers['Last-Modified']) if response.headers['Last-Modified']
  end
  
  def to_partial_path
    "sitemaps/#{self.class.to_s.underscore}"
  end
end
