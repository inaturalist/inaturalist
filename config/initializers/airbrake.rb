Airbrake.configure do |config|
  config.api_key = INAT_CONFIG['airbrake'].try(:[], 'api_key')
end
