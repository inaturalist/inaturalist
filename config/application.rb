# frozen_string_literal: true

require_relative "boot"

require "rails/all"

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require( *Rails.groups )

module Inaturalist
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.0
    config.active_record.belongs_to_required_by_default = false

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.enable_dependency_loading = true
    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W[#{config.root}/lib]

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.load_path += Dir[Rails.root.join( "config", "locales", "**", "*.{yml}" )]
    # config.i18n.default_locale = :de

    # JavaScript files you want as :defaults (application.js is always included).
    # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

    # Do not swallow errors in after_commit/after_rollback callbacks.
    # config.active_record.raise_in_transactional_callbacks = true

    # this might have to come back, was running into probs with Preferences
    # config.active_record.observers = :user_observer, :listed_taxon_sweeper
    config.active_record.observers = [:observation_sweeper, :user_sweeper]

    config.time_zone = "UTC"

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password, :password_confirmation]

    config.active_record.schema_format = :sql

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = "3.1"

    # Compile localized CSS:
    config.assets.precompile += ["*.css", "*.js"]

    # in case assets reference application objects or methods
    config.assets.initialize_on_precompile = true

    # Ensure bower components are included in the asset pipeline

    config.i18n.enforce_available_locales = false

    # new for Rails 4.2 as per https://github.com/collectiveidea/delayed_job
    config.active_job.queue_adapter = :delayed_job

    config.exceptions_app = routes

    config.active_record.yaml_column_permitted_classes = [Symbol, ActiveSupport::HashWithIndifferentAccess]

    config.action_controller.asset_host = proc do | _path, request |
      if Rails.env.production? && request && request.controller_instance
        site = request.controller_instance.instance_variable_get( "@site" )
        site && site.url
      end
    end

    config.to_prepare do
      Doorkeeper::ApplicationController.layout "application"
      # Rails 5 is more strict about what classes are allowed to be
      # subclasses. If a subclass constant gets reloaded but the parent
      # doesn't, the subclass is no longer considered a subclass of the
      # parent and you end up with ActiveRecord::SubclassNotFound errors,
      # which is probably going to happen a lot in a development and maybe a
      # test environment. According to
      # https://github.com/rails/rails/issues/29542, this is expected
      # behavior and the way to deal with it is to preload all these classes.
      # For other fun class reloading issues, see
      # https://stackoverflow.com/questions/29636334/a-copy-of-xxx-has-been-removed-from-the-module-tree-but-is-still-active
      begin
        require_dependency "check_list"
        require_dependency "denormalizer"
        require_dependency "eol_photo"
        require_dependency "flickr_photo"
        require_dependency "google_street_view_photo"
        require_dependency "list"
        require_dependency "local_photo"
        require_dependency "photo"
        require_dependency "picasa_photo"
        require_dependency "project_list"
        require_dependency "source"
        require_dependency "wikimedia_commons_photo"
      rescue ActiveRecord::NoDatabaseError, PG::ConnectionBad
        puts "Database not connected. Ignore if getting set up for the first time."
      end
    end

    config.action_mailer.preview_path = "#{Rails.root}/test/mailers/previews"

    config.middleware.use Rack::MobileDetect

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins "*"
        resource "/oauth/token", headers: :any, methods: [:post]
        resource "/oauth/revoke", headers: :any, methods: [:post]
        resource "/users/api_token", headers: :any, methods: [:get]
      end
    end

    config.middleware.use( Rack::Tracker ) do
      handler :google_global, {
        anonymize_ip: true,
        # working around the limitations of Rack::Tracker's ability to generate dynamic tracker IDs
        trackers: [
          {
            id: lambda {| env |
              return env["inat_ga_trackers"][0][1] if env["inat_ga_trackers"] && env["inat_ga_trackers"][0]
            }
          }, {
            id: lambda {| env |
              return env["inat_ga_trackers"][1][1] if env["inat_ga_trackers"] && env["inat_ga_trackers"][1]
            }
          }
        ]
      }
    end
  end
end

ActiveRecord::Base.include_root_in_json = false

ActiveRecord::SessionStore::Session.primary_key = "session_id"

Rack::Utils.multipart_part_limit = 2048

# load SiteConfig class and config
require "site_config"
CONFIG = SiteConfig.load
CONFIG.usingS3 = Rails.env.production? || Rails.env.prod_dev?

# A DEFAULT_SRID of -1 causes lots of warnings when running specs
# Keep it as -1 for production because existing data is based on it
DEFAULT_SRID = Rails.env.test? ? 0 : -1 # nofxx-georuby defaults to 4326.  Ugh.

# DelayedJob priorities
USER_PRIORITY = 0               # response to user action, should happen ASAP w/o bogging down a web proc
NOTIFICATION_PRIORITY = 1       # notifies user of something, not ASAP, but soon
USER_INTEGRITY_PRIORITY = 2     # maintains data integrity for stuff user's care about
INTEGRITY_PRIORITY = 3          # maintains data integrity for everything else, needs to happen, eventually
OPTIONAL_PRIORITY = 4           # inconsequential stuff like updating wikipedia summaries

# flickr api keys - these need to be set before Flickraw gets included
FlickRaw.api_key = CONFIG.flickr.key
FlickRaw.shared_secret = CONFIG.flickr.shared_secret
FlickRaw.check_certificate = false

# force encoding
Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

# TODO: is the geo_ruby stuff still used?
# make sure we have geojson support
require "georuby"
require "geo_ruby/ewk"
require "geo_ruby/geojson"
require "geo_ruby/shp"
require "geo_ruby/shp4r/shp"
require "geo_ruby/kml"
# geojson via RGeo
require "rgeo/geo_json"
# require 'google/api_client'
require "pp"
require "to_csv"
require "elasticsearch/model"
require "elasticsearch/rails/instrumentation"
require "inat_api_service"
require "google_recaptcha"
require "custom_log_formatter"

# elasticsearch-model won't load its WillPaginate support unless WillPaginate is
# loaded before it is. You can do this by specifying will_paginate before
# elasticsearch-model in the Gemfile, but that's a pretty opaque way to
# configure things. IMO, if we have to configure, we should configure
# explicitly. ~~~ kueda 20211006
Elasticsearch::Model::Response::Response.include(
  Elasticsearch::Model::Response::Pagination::WillPaginate
)
