::SecureHeaders::Configuration.configure do |config|
  config.hsts = false
  config.x_frame_options = 'DENY'
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = {:value => 1, :mode => 'block'}
  config.csp = {
    enforce: true,
    default_src: "self",
    img_src: "self *.githubusercontent.com *.google-analytics.com ",
    script_src: "self *.google-analytics.com 'unsafe-inline'",
    style_src: "self 'unsafe-inline'",
    :report_uri => '//example.com/uri-directive'
  }
end
