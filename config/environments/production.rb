Inaturalist::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local                   = false
  config.action_controller.perform_caching             = true
  config.action_view.cache_template_loading            = true

  config.eager_load = true

  config.action_dispatch.x_sendfile_header = CONFIG.x_sendfile_header

  # If you have no front-end server that supports something like X-Sendfile,
  # just comment this out and Rails will serve the files

  config.log_level = :info

  # Use a different cache store in production
  config.cache_store = :dalli_store, CONFIG.memcached,
    { compress: true, value_max_bytes: 1024 * 1024 * 3 }

  # Disable Rails's static asset server
  # In production, Apache or nginx will already do this
  config.serve_static_files = false

  # Allow removal of expired assets:
  config.assets.handle_expiration = true
  config.assets.expire_after 2.months

  # Compress JavaScripts and CSS
  # Choose the compressors to use (if any)
  config.assets.compress = true
  config.assets.js_compressor = Uglifier.new(:mangle => false)
  config.assets.css_compressor = :yui

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Enable serving of images, stylesheets, and javascripts from an asset server
  config.action_controller.asset_host = Proc.new {|*args|
    source, request = args
    host = CONFIG.assets_host || CONFIG.site_url
    "#{request ? request.protocol : 'http://'}#{host.sub(/^https?:\/\//, '')}"
  }

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false
  config.action_mailer.default_url_options = { :host => URI.parse(CONFIG.site_url).host }
  config.action_mailer.asset_host = config.action_controller.asset_host
  smtp_config_path = File.open("#{Rails.root}/config/smtp.yml")
  ActionMailer::Base.smtp_settings = YAML.load(smtp_config_path).symbolize_keys
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.default :charset => "utf-8"

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify
  
  config.middleware.use Rack::GoogleAnalytics, :trackers => lambda { |env|
    return env['inat_ga_trackers'] if env['inat_ga_trackers']
  }

  config.log_formatter = CustomLogFormatter.new

end
