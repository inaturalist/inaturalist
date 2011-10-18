# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true
# config.action_controller.cache_store                 = :file_store, "#{RAILS_ROOT}/cache"
config.cache_store                                   = :mem_cache_store, INAT_CONFIG["memcached"]
config.action_view.cache_template_loading            = true

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"

# Disable delivery errors if you bad email addresses should just be ignored
config.action_mailer.raise_delivery_errors = false

config.action_mailer.default_url_options = { :host => 'inaturalist.org' }
smtp_config_path = File.open("#{RAILS_ROOT}/config/smtp.yml")
ActionMailer::Base.smtp_settings = YAML.load(smtp_config_path)

# Set the logger to roll over monthly
config.logger = Logger.new("#{RAILS_ROOT}/log/#{ENV['RAILS_ENV']}.log", 10, 10485760)

# Only log events at the info level
config.logger.level = Logger::Severity::INFO