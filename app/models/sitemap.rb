require 'benchmark'
class Sitemap
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations

  attr_reader :url, :input_content

  class HttpValidations < ActiveModel::Validator
    include ActionView::Helpers::NumberHelper
    
    def validate sitemap
      return if sitemap.input_content
      errors = {}
      warnings = {}
      ok = {}
      
      
      if sitemap.response.status == 200 
        ok["Status"] = "OK"
      else
        errors["Status"] = sitemap.response.status 
      end

      if Sitemap.valid_http_content_types.include? sitemap.response.headers['Content-Type']
        ok["Content-Type"] = sitemap.response.headers['Content-Type']
      else
        errors["Content-Type"] = sitemap.response.headers['Content-Type'] 
      end  

      if sitemap.timing < 2
        ok["Response Time"] = "#{sitemap.timing}s"
      elsif sitemap.timing < 10
        warnings["Response Time"] = "#{sitemap.timing}s"
      else
        errors["Response Time"] = "#{sitemap.timing}s"
      end
      
      if sitemap.length > 0
        ok["Response items"] = number_with_delimiter(sitemap.length)
      else
        warnings["Response items"] = number_with_delimiter(sitemap.length)
      end
      
      if sitemap.response.body.length < 10.megabytes
        ok["Response Size"] = number_to_human_size(sitemap.response.body.length)
      else
        warnings["Response Size"] = number_to_human_size(sitemap.response.body.length)
      end

      sitemap.errors["HTTP"] = {} unless errors.empty?
      sitemap.errors.set("HTTP", errors) unless errors.empty?
      sitemap.warnings["HTTP"] = {} unless warnings.empty?
      sitemap.warnings.set("HTTP", warnings) unless warnings.empty?
      sitemap.ok["HTTP"] = {} unless ok.empty?
      sitemap.ok.set("HTTP", ok) unless ok.empty?
    end
  end
  validates_with HttpValidations
  
  def self.valid_capabilities
    ['description', 'capabilitylist', 'resourcelist', 'resourcedump', 'resourcedump-manifest','changelist', 'changedump', 'changedump-manifest']
  end
  
  def self.valid_http_content_types
    ["application/xml", "text/xml"]
  end
  
  def ok
    @ok ||= ActiveModel::Errors.new(self)
  end
  
  def warnings
    @warnings ||= ActiveModel::Errors.new(self)
  end
  
  def validations_for key
    @validations_for ||= {}
    @validations_for[key] ||= [:errors, :warnings, :ok].map do |x|
      send(x).get(key) || {}
    end.flatten.inject([]) do |memo, v|
      memo += v.keys
    end
  end
  
  def initialize options = {}
    case
    when options[:url]
      initialize_by_url options
    when options[:input_content]
      initialize_by_data options
    end
  end
  
  def initialize_by_url options
    @url = options[:url]
    
    unless @url.starts_with? 'http'
      @url = "http://#{@url}"
    end
  end
  
  def initialize_by_data options
    @content = @input_content = options[:input_content]
    @response = OpenStruct.new(headers: { }, body: @content)
    @timing = -1
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
  
  def sitemap?
    index? || doc.xpath('sm:urlset', sm: "http://www.sitemaps.org/schemas/sitemap/0.9").any?
  end
  
  def resourcesync?
    doc.root.xpath('rs:md[@capability]', rs: "http://www.openarchives.org/rs/terms/").any?
  end
  
  self.valid_capabilities.each do |c|
    define_method "#{c.underscore}?" do
      doc.root.xpath("rs:md[@capability=\"#{c}\"]", rs: "http://www.openarchives.org/rs/terms/").any?
    end
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
    x = doc.root.xpath("rs:md", rs: "http://www.openarchives.org/rs/terms/").first
    if x
      Hash[x.attributes.map { |k,v| [k, v.to_s] }]
    else
      {}
    end 
  end
  
  def required_attributes
    
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
