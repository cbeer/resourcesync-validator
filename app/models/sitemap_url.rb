class SitemapUrl < OpenStruct
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  
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
  
end
