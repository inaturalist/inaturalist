Rails.application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  config.eager_load = true

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
  # config.cache_store = :mem_cache_store, CONFIG.memcached

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true
  # https://stackoverflow.com/a/51898048
  config.assets.check_precompiled_asset = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin
  
  config.active_support.deprecation = :log

  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  config.public_file_server.enabled = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
end

