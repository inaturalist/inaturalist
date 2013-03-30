Airbrake.configure do |config|
  config.api_key = CONFIG.airbrake.api_key
  if CONFIG.airbrake.disable
    config.development_environments << Rails.env
  end
end
