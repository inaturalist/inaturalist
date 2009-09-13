# Be sure to restart your server when you modify this file

# Uncomment below to force Rails into production mode when
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.1.1' unless defined? RAILS_GEM_VERSION
# RAILS_GEM_VERSION = '2.2.0' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

require 'yaml'
configuration_bindings = YAML.load(File.open("#{RAILS_ROOT}/config/config.yml"))

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.
  # See Rails::Configuration for more options.

  # Skip frameworks you're not going to use (only works if using vendor/rails).
  # To use Rails without a database, you must remove the Active Record framework
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Only load the plugins named here, in the order given. By default, all plugins 
  # in vendor/plugins are loaded in alphabetical order.
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Your secret key for verifying cookie session data integrity.
  # If you change this key, all old sessions will become invalid!
  # Make sure the secret is at least 30 characters and all random, 
  # no regular words or you'll be exposed to dictionary attacks.
  config.action_controller.session = {
    :session_key => configuration_bindings['base']['rails']['secret'],
    :secret      => configuration_bindings['base']['rails']['secret']
  }

  # Use the database for sessions instead of the cookie-based default,
  # which shouldn't be used to store highly confidential information
  # (create the session table with 'rake db:sessions:create')
  # config.action_controller.session_store = :active_record_store

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc
  
  # Added from the acts_as_authenticated plugin 6/3/07
  config.active_record.observers = :user_observer, :listed_taxon_sweeper
  
  # Gems
  config.gem 'mislav-will_paginate', :version => '2.3.4',  :lib => 'will_paginate', :source => 'http://gems.github.com'
  config.gem 'rubyist-aasm', :lib => 'aasm', :source => 'http://gems.github.com', :version => '2.0.2'

  #TODO: make all these work...
  config.gem "ruby-debug"
  config.gem "GeoRuby", :lib => 'geo_ruby'
  config.gem "mojombo-chronic", :lib => 'chronic', :source => 'http://gems.github.com'
  config.gem "BlueCloth", :lib => 'bluecloth'
  config.gem "htmlentities"
  config.gem "right_http_connection"
  config.gem "right_aws"
  config.gem "mocha"
  config.gem "thoughtbot-paperclip", :lib => 'paperclip', :source => 'http://gems.github.com'
  config.gem "ambethia-smtp-tls", :lib => "smtp-tls", :source => "http://gems.github.com/"
  config.gem "kueda-flickraw", :lib => "flickraw", :source => "http://gems.github.com/"
  config.gem 'rest-client', :lib => 'rest_client'
  config.gem "carlosparamio-geoplanet", :lib => 'geoplanet', :source => "http://gems.github.com/"
  config.gem 'geoip'

  # Can't do this until Rails starts including the rake tasks of plugin gems
  # config.gem "freelancing-god-thinking-sphinx", :lib => 'thinking_sphinx', 
  #   :source => 'http://gems.github.com'
  
  # Set default time zone to UTC
  config.time_zone = 'UTC'
end

# Windows flag, for disabling things that might not work in Windoze
WINDOWS = false

require 'net-flickr/lib/net/flickr'
require 'catalogue_of_life'
require 'ubio'
require 'model_tips'
require 'meta_service'
require 'wikipedia_service'
require 'batch_tools'
require 'georuby_extra'

# GeoIP setup, for IP geocoding
geoip_config = YAML.load(File.open("#{RAILS_ROOT}/config/geoip.yml"))
GEOIP = GeoIP.new(geoip_config[RAILS_ENV]['city'])


### API KEYS ###
UBIO_KEY = configuration_bindings['base']['ubio']['UBIO_KEY']

# Yahoo Developer Network
YDN_APP_ID = configuration_bindings['base']['yahoo_dev_network']['YDN_APP_ID']
GeoPlanet.appid = YDN_APP_ID


# Google Analytics configs
# See http://www.rubaidh.com/projects/google-analytics-plugin/
Rubaidh::GoogleAnalytics.tracker_id   = configuration_bindings['base']['google_analytics']['tracker_id']
Rubaidh::GoogleAnalytics.domain_name  = configuration_bindings['base']['google_analytics']['domain_name']
Rubaidh::GoogleAnalytics.environments = ['production']

# General settings
SITE_NAME = configuration_bindings['base']['general']['SITE_NAME']
OBSERVATIONS_TILE_SERVER = configuration_bindings[Rails.env]['tile_servers']['observations']
SPHERICAL_MERCATOR = SphericalMercator.new
