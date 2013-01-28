Airbrake.configure do |config|
  config.api_key = CONFIG.get(:airbrake, :api_key)
end
