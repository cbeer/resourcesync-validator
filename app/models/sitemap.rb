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
      discover_and_fetch_sitemap @url
    end
  end
  
  def discover_and_fetch_sitemap url
    url = URI.parse url

    Faraday.get url
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
  
  def sitemap?
    index? || doc.xpath('sm:urlset', sm: "http://www.sitemaps.org/schemas/sitemap/0.9").any?
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
    sitemap_schema.valid? doc
  end

  def schema_errors
    @sitemap_validation_errors ||= sitemap_schema.validate doc
  end
  
  def sitemap_schema
    if index?
      joint_index_schema
    else
      joint_sitemap_schema
    end
  end

  def joint_index_schema
    $sitemap_index_schema ||= Nokogiri::XML::Schema <<-EOF
    <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified">
    <xs:import namespace="http://www.openarchives.org/rs/terms/" schemaLocation="http://www.openarchives.org/rs/0.9.1/resourcesync.xsd" />
    <xs:import namespace="http://www.sitemaps.org/schemas/sitemap/0.9" schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9/siteindex.xsd" />
    </xs:schema>
    EOF
  end
  
  def joint_sitemap_schema
    $sitemap_schema ||= Nokogiri::XML::Schema <<-EOF
    <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified">
    <xs:import namespace="http://www.openarchives.org/rs/terms/" schemaLocation="http://www.openarchives.org/rs/0.9.1/resourcesync.xsd" />
    <xs:import namespace="http://www.sitemaps.org/schemas/sitemap/0.9" schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd" />
    </xs:schema>
    EOF
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
    h = {}
    
    doc.root.xpath("rs:ln", rs: "http://www.openarchives.org/rs/terms/").map do |x| 
      ln = Hash[x.attributes.map { |k,v| [k, v.to_s]}]
      h[ln["rel"]] ||= []
      h[ln["rel"]] << ln
    end
    
    h
  end
  
  def length
    urls.length + sitemaps.length
  end
end
