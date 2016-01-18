require File.expand_path('../boot', __FILE__)
require 'rails/all'

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Inaturalist
  class Application < Rails::Application

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/lib)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # JavaScript files you want as :defaults (application.js is always included).
    # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true
    
    # config.active_record.observers = :user_observer, :listed_taxon_sweeper # this might have to come back, was running into probs with Preferences
    config.active_record.observers = [ :observation_sweeper, :user_sweeper, :update_observer ]
    
    config.time_zone = 'UTC'
    
    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password, :password_confirmation]

    config.active_record.schema_format = :sql

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.6'

    # Compile localized CSS:
    config.assets.precompile += ['*.css', '*.js']

    # in case assets reference application objects or methods
    config.assets.initialize_on_precompile = true

    config.i18n.enforce_available_locales = false

    # new for Rails 4.2 as per https://github.com/collectiveidea/delayed_job
    config.active_job.queue_adapter = :delayed_job

    config.exceptions_app = self.routes

    config.to_prepare do
      Doorkeeper::ApplicationController.layout "application"
    end

    config.middleware.insert_before "ActionDispatch::DebugExceptions", "LogstasherCatchAllErrors"
  end

end

ActiveRecord::Base.include_root_in_json = false

Rack::Utils.multipart_part_limit = 2048

# load SiteConfig class and config
require "site_config"
CONFIG = SiteConfig.load

# flickr api keys - these need to be set before Flickraw gets included
FLICKR_API_KEY = CONFIG.flickr.key
FLICKR_SHARED_SECRET = CONFIG.flickr.shared_secret
# A DEFAULT_SRID of -1 causes lots of warnings when running specs
# Keep it as -1 for production because existing data is based on it
DEFAULT_SRID = Rails.env.test? ? 0 : -1 # nofxx-georuby defaults to 4326.  Ugh.

# DelayedJob priorities
USER_PRIORITY = 0               # response to user action, should happen ASAP w/o bogging down a web proc
NOTIFICATION_PRIORITY = 1       # notifies user of something, not ASAP, but soon
USER_INTEGRITY_PRIORITY = 2     # maintains data integrity for stuff user's care about
INTEGRITY_PRIORITY = 3          # maintains data integrity for everything else, needs to happen, eventually
OPTIONAL_PRIORITY = 4           # inconsequential stuff like updating wikipedia summaries

### API KEYS ###
UBIO_KEY = CONFIG.ubio.key

# Yahoo Developer Network
YDN_APP_ID = CONFIG.yahoo_dev_network.app_id
GeoPlanet.appid = YDN_APP_ID

FlickRaw.api_key = FLICKR_API_KEY
FlickRaw.shared_secret = FLICKR_SHARED_SECRET
FlickRaw.check_certificate = false
# FlickRaw.ca_path = "/etc/ssl/certs" if File.exists?("/etc/ssl/certs")

# General settings
SITE_NAME = CONFIG.site_name
SITE_NAME_SHORT = CONFIG.site_name_short || SITE_NAME

# force encoding
Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

# TODO: is the geo_ruby stuff still used?
# make sure we have geojson support
require 'geo_ruby'
require 'geo_ruby/geojson'
require 'geo_ruby/shp4r/shp'
require 'geo_ruby/kml'
# geojson via RGeo
require 'rgeo/geo_json'
require 'google/api_client'
require 'pp'
require 'to_csv'
require 'elasticsearch/model'
require 'elasticsearch/rails/instrumentation'
require 'angular-rails-templates'
