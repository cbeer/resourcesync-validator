require 'benchmark'
class Sitemap
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :url
  
  def initialize options = {}
    case
    when options[:url]
      initialize_by_url options
      
    end
  end
  
  def initialize_by_url options
    @url = options[:url]
    
    unless @url.starts_with? 'http'
      @url = "http://#{@url}"
    end
  end
  
  def content
    @content ||= begin
      Zlib::GzipReader.new( StringIO.new(response.body) ).read
    rescue Zlib::GzipFile::Error
      response.body
    end
  end
  
  def timing
    response
    @timing
  end
  
  def response
    @response ||= recording_timing_information(:@timing) do
      Faraday.get @url
    end
  end
  
  def recording_timing_information as, &block
    tmp = nil
    
    timing = Benchmark.realtime do 
      tmp = yield
    end
    
    instance_variable_set(as, timing)

    tmp
  end
  
  def doc
    @doc ||= Nokogiri::XML(content)
  end
  
  def persisted?
    false
  end
  
  def valid?
    !!content
  end
  
  def resourcesync?
    doc.root.xpath('rs:md[@capability]', rs: "http://www.openarchives.org/rs/terms/").any?
  end
  
  def changelist?
    doc.root.xpath('rs:md[@capability="changelist"]', rs: "http://www.openarchives.org/rs/terms/").any?
  end
  
  def capabilitylist?
    doc.root.xpath('rs:md[@capability="capabilitylist"]', rs: "http://www.openarchives.org/rs/terms/").any?
  end
  
  def resourcelist?
    doc.root.xpath('rs:md[@capability="resourcelist"]', rs: "http://www.openarchives.org/rs/terms/").any?
  end
  
  def xmlns
    default_xmlns
  end
  
  def default_xmlns
    "http://www.sitemaps.org/schemas/sitemap/0.9"
  end
  
  def index?
    doc.xpath("sm:sitemapindex", sm: xmlns).any?
  end
  
  def sitemaps
    doc.xpath("//sm:sitemap", sm: xmlns).map do |s|
      OpenStruct.new({doc: s}.merge(Hash[s.children.map { |n| [n.name,n.inner_text]}]))
    end
  end
  
  def schema_valid?
    sitemap_valid? && resync_valid? 
  end
  
  def sitemap_valid?
    sitemap_schema.valid? doc
  end
  
  def resync_valid?
    resync_schema.valid? doc
  end
  
  def sitemap_validation_errors
    @sitemap_validation_errors ||= sitemap_schema.validate doc
  end

  def resync_validation_errors
    @resync_validation_errors ||= resync_schema.validate doc
  end
  
  def sitemap_schema
    if index?
      $sitemap_index_schema ||= Nokogiri::XML::Schema(Faraday.get("http://www.sitemaps.org/schemas/sitemap/0.9/siteindex.xsd").body)
    else
      $sitemap_schema ||= Nokogiri::XML::Schema(Faraday.get("http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd").body)
    end
  end
  
  def resync_schema
    $resync_schema ||= Nokogiri::XML::Schema(Faraday.get("http://www.openarchives.org/rs/0.9.1/resourcesync.xsd").body)
  end
  
  def urls
    doc.xpath("//sm:url", sm: xmlns).map do |s|
      h = {}
      s.children.each do |n| 
        if n.inner_text.blank? && n.attributes.any?
          h[n.name] ||= []
          h[n.name] << Hash[n.attributes.map { |k,v| [k,v.to_s] }]
        else
          h[n.name] = n.inner_text
        end
      end
      OpenStruct.new({doc: s}.merge(h))
    end
  end
  
  def md
    doc.root.xpath("rs:md", rs: "http://www.openarchives.org/rs/terms/").map { |x| Hash[x.attributes.map { |k,v| [k, v.to_s]}] }
  end
  
  def ln
    doc.root.xpath("rs:ln", rs: "http://www.openarchives.org/rs/terms/").map { |x| Hash[x.attributes.map { |k,v| [k, v.to_s]}] }
  end
end
