Inaturalist::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  # config.action_view.debug_rjs             = true
  config.action_controller.perform_caching = false
  
  # Uncomment these to test caching
  # ActionController::Base.cache_store = :file_store, Rails.root + "/tmp/cache"
  # config.action_controller.perform_caching             = true
  # config.action_view.cache_template_loading            = true

  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { :host => 'localhost:3000' }
  smtp_config_path = File.open("#{Rails.root}/config/smtp.yml")
  ActionMailer::Base.smtp_settings = YAML.load(smtp_config_path)
  config.action_mailer.delivery_method = :test

# # Uncomment these to test caching
# config.cache_store = :file_store, RAILS_ROOT + "/tmp/cache"
config.cache_store = :mem_cache_store, INAT_CONFIG["memcached"]
# config.action_controller.perform_caching             = true
# config.action_view.cache_template_loading            = true
# config.cache_classes = true
  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin
  
  config.active_support.deprecation = :log
end

