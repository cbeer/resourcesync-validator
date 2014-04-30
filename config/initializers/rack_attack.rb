# Throttle requests to 5 requests per second per ip
Rack::Attack.throttle('validate/req/ip', :limit => 5, :period => 1.second) do |req|
  req.ip if req.path.start_with? '/validate'
end
