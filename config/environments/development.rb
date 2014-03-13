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
  config.action_controller.perform_caching = false

  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { :host => 'localhost:3000' }
  config.action_mailer.delivery_method = :test

  # # Uncomment to test mail delivery
  # smtp_config_path = File.open("#{Rails.root}/config/smtp.yml")
  # ActionMailer::Base.smtp_settings = YAML.load(smtp_config_path).symbolize_keys
  # config.action_mailer.delivery_method = :smtp  

  # Uncomment these to test caching
  # config.action_controller.perform_caching             = true
  # config.action_view.cache_template_loading            = true
  # config.cache_classes = true
  config.cache_store = :mem_cache_store, CONFIG.memcached

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin
  
  config.active_support.deprecation = :log
  # config.middleware.use MailView::Mapper, [EmailerPreview] # TODO maybe include this in Gemfile
end

