require 'benchmark'

##
# Validate a Sitemap.org and ResourceSync document
class Sitemap
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  include Sitemap::Validations

  attr_reader :url, :input_content

  def self.valid_capabilities
    ['description', 'capabilitylist', 'resourcelist', 'resourcedump', 'resourcedump-manifest','changelist', 'changedump', 'changedump-manifest']
  end
  
  def self.sitemap_xmlns
    "http://www.sitemaps.org/schemas/sitemap/0.9"
  end
  
  def xmlns
    self.class.sitemap_xmlns
  end

  self.valid_capabilities.each do |c|
    define_method "#{c.underscore}?" do
      doc.root.xpath("rs:md[@capability=\"#{c}\"]", rs: "http://www.openarchives.org/rs/terms/").any?
    end
  end
  
  def self.valid_http_content_types
    ["application/xml", "text/xml", "application/x-gzip"]
  end
  
  ##
  # Merge the sitemapindex and resourcesync schemas
  # @return [Nokogiri::XML::Schema] schema
  def self.joint_index_schema
    @sitemap_index_schema ||= Nokogiri::XML::Schema <<-EOF
    <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified">
    <xs:import namespace="http://www.openarchives.org/rs/terms/" schemaLocation="http://www.openarchives.org/rs/0.9.1/resourcesync.xsd" />
    <xs:import namespace="http://www.sitemaps.org/schemas/sitemap/0.9" schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9/siteindex.xsd" />
    </xs:schema>
    EOF
  end
  
  ##
  # Merge the sitemapindex and resourcesync schemas
  # @return [Nokogiri::XML::Schema] schema
  def self.joint_sitemap_schema
    @sitemap_schema ||= Nokogiri::XML::Schema <<-EOF
    <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified">
    <xs:import namespace="http://www.openarchives.org/rs/terms/" schemaLocation="http://www.openarchives.org/rs/0.9.1/resourcesync.xsd" />
    <xs:import namespace="http://www.sitemaps.org/schemas/sitemap/0.9" schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd" />
    </xs:schema>
    EOF
  end
  
  def initialize options = {}
    case
    when options[:url]
      initialize_by_url options
    when options[:input_content]
      initialize_by_data options
    end
  end
  
  ##
  # Initialize the sitemap from a URL
  def initialize_by_url options
    @url = options[:url]
    
    unless @url.starts_with? 'http'
      @url = "http://#{@url}"
    end
  end
  
  ##
  # Initialize the sitemap from some provided sitemap document
  def initialize_by_data options
    @content = @input_content = options[:input_content]
    @response = OpenStruct.new(headers: { }, body: @content)
    @timing = -1
  end

  validates_with Validations::HttpValidations
  validates_with Validations::SchemaValidations
  validates_with Validations::LinkValidations
  validates_with Validations::MdValidations

  ##
  # Fetch the sitemap from the given URL
  def response
    @response ||= recording_timing_information(:@timing) do
      discover_and_fetch_sitemap @url
    end
  end
  
  ##
  # Duration for retrieving the response
  def timing
    response
    @timing
  end
  
  ##
  # Get the document content from the URL, ungzipping if necessary
  def content
    @content ||= begin
      Zlib::GzipReader.new( StringIO.new(response.body) ).read
    rescue Zlib::GzipFile::Error
      response.body
    end
  end

  ##
  # Parse the document as XML
  def doc
    @doc ||= Nokogiri::XML(content)
  end

  ##
  # Is the document even a sitemap?
  def sitemap?
    index? || urlset?
  end
  
  ##
  # Is the document a sitemapindex?
  def index?
    doc.xpath("sm:sitemapindex", sm: xmlns).any?
  end
  
  ##
  # Is the document a urlset?
  def urlset?
    doc.xpath('sm:urlset', sm: xmlns).any?
  end
  
  ##
  # Does the document have resourcesync attributes?
  def resourcesync?
    doc.root.xpath('rs:md[@capability]', rs: "http://www.openarchives.org/rs/terms/").any?
  end
  
  ##
  # Get the associated sitemap documents for this sitemap index 
  def sitemaps
    doc.xpath("//sm:sitemap", sm: xmlns).map do |s|
      SitemapIndexUrl.from_fragment s
    end
  end
  
  ##
  # Get the associated URLs for this sitemap
  def urls
    doc.xpath("//sm:url", sm: xmlns).map do |s|
      SitemapUrl.from_fragment s
    end
  end
  
  ##
  # Count the number of documents in the sitemap 
  def length
    if index?
      sitemaps.length
    else
      urls.length
    end
  end
  
  ##
  # Is the document schema-valid?
  def schema_valid?
    sitemap_schema.valid? doc
  end

  ##
  # Get the schema validation errors
  def schema_errors
    @sitemap_validation_errors ||= sitemap_schema.validate doc
  end
  
  ##
  # Get the schema appropriate to the content type
  def sitemap_schema
    if index?
      self.class.joint_index_schema
    else
      self.class.joint_sitemap_schema
    end
  end
  
  ##
  # Get the top-level resourcesync metadata
  def md
    x = doc.root.xpath("rs:md", rs: "http://www.openarchives.org/rs/terms/").first
    if x
      Hash[x.attributes.map { |k,v| [k, v.to_s] }]
    else
      {}
    end 
  end

  ##
  # Get the resourcesync lns
  def lns
    doc.root.xpath("rs:ln", rs: "http://www.openarchives.org/rs/terms/").map do |x| 
      Hash[x.attributes.map { |k,v| [k, v.to_s]}]
    end
  end
  
  ##
  # Get the resourcesync lns grouped by the relationship
  def lns_by_rel
    @lns_by_rel ||= lns.group_by { |x| x['rel'] }
  end

  ##
  # Get the resourcesync changelist grouped by the change type
  def changes
    @changes ||= urls.group_by { |x| (x.md || {})["change"] } if changelist? or changedump?
  end
  
  def persisted?
    false
  end

  private
  
  ##
  # Fetch the content of the URL
  # @params [String] url URL to fetch
  # @return [Faraday::Response]
  def discover_and_fetch_sitemap url
    url = URI.parse url

    Faraday.get url
  end
  
  ##
  # Record the time it takes to execute the block in the instance variable given
  # @param [Symbol] as an instance variable name, e.g. :@timing
  def recording_timing_information as, &block
    tmp = nil
    
    timing = Benchmark.realtime do 
      tmp = yield
    end
    
    instance_variable_set(as, timing)

    tmp
  end
  
end
