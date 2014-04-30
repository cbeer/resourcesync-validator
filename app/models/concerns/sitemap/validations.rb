##
# Validation helpers for sitemaps
module Sitemap::Validations
  
  # Validation methods
  # Note: the method #errors is provided by ActiveModel::Validations
  
  ##
  # If a check completed successfully, it is recorded here
  # @return [ActiveModel::Errors] results
  def ok
    @ok ||= ActiveModel::Errors.new(self)
  end
  
  ##
  # If a check completed, but wasn't a total failure, it is recorded here
  # @return [ActiveModel::Errors] results
  def warnings
    @warnings ||= ActiveModel::Errors.new(self)
  end
  
  def valid?
    return @valid if instance_variable_defined? :@valid
    @valid ||= super
  end
  
  ##
  # Get the full list of validations performed
  def validations_for key
    (errors.keys + warnings.keys + ok.keys).select do |x|
      x.to_s.starts_with? key
    end
  end
  
  ##
  # Validate HTTP response codes and report ok, warnings, and errors
  class HttpValidations < ActiveModel::Validator
    include ActionView::Helpers::NumberHelper
    
    ##
    # Validate a sitemap
    # @params [Sitemap] sitemap
    def validate sitemap
      return if sitemap.input_content
      
      if sitemap.response.status == 200 
        sitemap.ok.add "http_Status", "OK"
      else
        sitemap.errors.add "http_Status", sitemap.response.status 
      end

      if Sitemap.valid_http_content_types.include? sitemap.response.headers['Content-Type']
        sitemap.ok.add "http_Content-Type", sitemap.response.headers['Content-Type']
      else
        sitemap.errors.add "http_Content-Type", sitemap.response.headers['Content-Type'] 
      end  

      if sitemap.timing < 2
        sitemap.ok.add "http_Response Time", "#{sitemap.timing}s"
      elsif sitemap.timing < 10
        sitemap.warnings.add "http_Response Time", "#{sitemap.timing}s"
      else
        sitemap.errors.add "http_Response Time", "#{sitemap.timing}s"
      end
      
      if sitemap.length > 0
        sitemap.ok.add "http_Response items", number_with_delimiter(sitemap.length)
      else
        sitemap.warnings.add "http_Response items", number_with_delimiter(sitemap.length)
      end
      
      if sitemap.response.body.length < 10.megabytes
        sitemap.ok.add "http_Response Size", number_to_human_size(sitemap.response.body.length)
      else
        sitemap.warnings.add "http_Response Size", number_to_human_size(sitemap.response.body.length)
      end
    end
  end

  ##
  # Perform schema validation for the document
  class SchemaValidations < ActiveModel::Validator
    include ActionView::Helpers::NumberHelper
    
    ##
    # Validate a sitemap
    # @params [Sitemap] sitemap
    def validate sitemap
      
      if sitemap.sitemap?
        sitemap.ok.add 'xsd_Sitemap', "Present"
      else
        sitemap.errors.add 'xsd_Sitemap', "Missing"
      end

      if sitemap.resourcesync?
        sitemap.ok.add 'xsd_Resource Sync', "Present"
      else
        sitemap.warnings.add 'xsd_Resource Sync', "Missing"
      end
      
      if sitemap.schema_valid?
        sitemap.ok.add 'xsd_Schema Valid', "Yes"
      else
        sitemap.errors.add 'xsd_Schema Valid', "No"
      end
    end
  end

  ##
  # Validate top-level ResourceSync ln elements
  class LinkValidations < ActiveModel::Validator
    include ActionView::Helpers::NumberHelper
    
    ##
    # Validate a sitemap
    # @params [Sitemap] sitemap
    def validate sitemap
      return unless sitemap.resourcesync?

      if sitemap.lns_by_rel['describedby'].blank?
        sitemap.warnings.add 'rs:ln_describedby', "Missing"
      end
      
      if sitemap.lns_by_rel['up'].blank? and !sitemap.description?
        sitemap.warnings.add 'rs:ln_up', "Missing"
      end
    end
  end

  ##
  # Validate top-level ResourceSync md elements
  class MdValidations < ActiveModel::Validator
    include ActionView::Helpers::NumberHelper
    
    ##
    # Validate a sitemap
    # @params [Sitemap] sitemap
    def validate sitemap
      return unless sitemap.resourcesync?

      (required_md_attributes(sitemap) - sitemap.md.keys).each do |k|
        sitemap.errors.add "rs:md_#{k}", "Missing"
      end

      (preferred_md_attributes(sitemap) - sitemap.md.keys).each do |k|
        sitemap.warnings.add "rs:md_#{k}", "Missing"
      end
    end
    
    private
    ##
    # List of required resourcesync metadata attributes for the resourcesync capability
    def required_md_attributes sitemap
      required_attributes = []
      if (sitemap.resourcelist? || sitemap.resourcedump? || sitemap.resourcedump_manifest?)
        required_attributes << 'at'
      end
      
      if (sitemap.changelist? or sitemap.changedump?)
        required_attributes << 'from'
      end
      
      required_attributes
    end
    
    ##
    # List of recommended resourcesync metadata attributes for the resourcesync capability
    def preferred_md_attributes sitemap
      preferred_md_attributes = []
      if (sitemap.changelist? or sitemap.changedump? or sitemap.changedump_manifest?)
        preferred_md_attributes << 'until'
      end
      preferred_md_attributes
    end
  end
end
