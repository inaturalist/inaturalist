# frozen_string_literal: true

require "simplecov"
SimpleCov.start

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] = "test"
require File.expand_path( "../config/environment", __dir__ )

require "rspec/rails"
require "factory_bot_rails"
require "capybara/rails"
require "webmock/rspec"
WebMock.allow_net_connect!
require File.expand_path( "#{File.dirname( __FILE__ )}/blueprints" )
require File.expand_path( "#{File.dirname( __FILE__ )}/helpers/make_helpers" )
require File.expand_path( "#{File.dirname( __FILE__ )}/helpers/example_helpers" )
require File.expand_path( "#{File.dirname( __FILE__ )}/../lib/eol_service.rb" )
require File.expand_path( "#{File.dirname( __FILE__ )}/../lib/meta_service.rb" )
require File.expand_path( "#{File.dirname( __FILE__ )}/../lib/flickr_cache.rb" )

# rubocop:disable Style/MixinUsage
include MakeHelpers
# rubocop:enable Style/MixinUsage

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join( "spec/support/**/*.rb" )].sort.each {| f | require f }

RSpec.configure do | config |
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  #
  # == Notes
  #
  # For more information take a look at Spec::Runner::Configuration and Spec::Runner

  config.before( :suite ) do
    DatabaseCleaner.strategy = :transaction
    Elasticsearch::Model.client.ping
    es_classes = [
      ControlledTerm,
      Identification,
      ObservationField,
      Observation,
      Place,
      Project,
      Taxon,
      UpdateAction,
      User
    ].freeze
    print "Rebuilding #{es_classes.size} indexes"
    es_classes.each do | klass |
      print "."
      begin
        klass.__elasticsearch__.delete_index!
      rescue StandardError => e
        raise e unless e.class.to_s =~ /NotFound/
      end
      klass.__elasticsearch__.create_index!
      ElasticModel.wait_until_index_exists( klass.index_name, timeout: 1 )
    end
    puts
  end

  config.before( :each ) do
    DatabaseCleaner.start
    Delayed::Job.delete_all
    make_default_site
    CONFIG.has_subscribers = :disabled
  end

  config.after( :each ) do
    DatabaseCleaner.clean
    CONFIG.has_subscribers = :enabled
  end

  config.before( :all ) do
    DatabaseCleaner.clean_with( :truncation, { except: %w(spatial_ref_sys) } )
    [PlaceGeometry, Observation, TaxonRange].each do | klass |
      begin
        Rails.logger.debug "[DEBUG] dropping enforce_srid_geom on place_geometries"
        ActiveRecord::Base.connection.execute(
          "ALTER TABLE #{klass.table_name} DROP CONSTRAINT IF EXISTS enforce_srid_geom"
        )
      rescue ActiveRecord::StatementInvalid
        # already dropped
      end
      # ensure spatial_ref_sys has a vanilla WGS84 "projection"
      begin
        ActiveRecord::Base.connection.execute(
          <<~SQL
            INSERT INTO spatial_ref_sys
            VALUES (
              4326,
              'EPSG',
              4326,
              'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4326"]]', '+proj=longlat +datum=WGS84 +no_defs'
            )
          SQL
        )
      rescue PG::Error, ActiveRecord::RecordNotUnique => e
        raise e unless e.message =~ /duplicate key/
      end
    end
  end

  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :view
  config.include RSpecHtmlMatchers
  config.include FactoryBot::Syntax::Methods
  config.fixture_path = "#{::Rails.root}/spec/fixtures/"
  config.infer_spec_type_from_file_location!
  # disable certain specs. Useful for travis
  config.filter_run_excluding disabled: true
end

Shoulda::Matchers.configure do | config |
  config.integrate do | with |
    with.test_framework :rspec
    with.library :rails
  end
end

# Pretend Delayed Job doesn't exist and run all jobs when they are queued
def without_delay
  Delayed::Worker.delay_jobs = false
  r = yield
  Delayed::Worker.delay_jobs = true
  r
end

# Invoke jobs *after* the block executes, which is closer to what happens in
# production. ignore_run_at will ignore any run_at scheduling, so *all* queued
# jobs get invoked immediately after the block
def after_delayed_job_finishes( ignore_run_at: false )
  r = yield
  if ignore_run_at
    Delayed::Job.find_each( &:invoke_job )
  else
    Delayed::Worker.new.work_off
  end
  r
end

# inject a fixture check into API wrappers.  Need to stop making HTTP requests in tests
class EolService
  alias real_request request
  def request( method, *args )
    uri = get_uri( method, *args )
    fname = "#{uri.path}_#{uri.query}".gsub( %r{[/.]+}, "_" ).gsub( "&", "-" )
    fixture_path = File.expand_path( File.dirname( __FILE__ ) + "/fixtures/eol_service/#{fname}" )
    if File.exist?( fixture_path )
      # puts "[DEBUG] Loading cached EOL response for #{uri}: #{fixture_path}"
      File.open( fixture_path ) do | f |
        Nokogiri::XML( f )
      end
    else
      cmd = "wget -O \"#{fixture_path}\" \"#{uri}\""
      # puts "[DEBUG] Couldn't find EOL response fixture, you should probably do this:\n #{cmd}"
      puts "Caching API response, running #{cmd}"
      system cmd
      real_request( method, *args )
    end
  end
end

class MetaService
  class << self
    alias real_fetch_with_redirects fetch_with_redirects
    def fetch_with_redirects( options, attempts = 3 )
      uri = options[:request_uri]
      fname = uri.to_s.parameterize
      fixture_path = File.expand_path( File.dirname( __FILE__ ) + "/fixtures/#{name.underscore}/#{fname}" )
      if File.exist?( fixture_path )
        File.open( fixture_path ) do | f |
          return OpenStruct.new( body: f.read )
        end
      else
        cmd = "wget -O \"#{fixture_path}\" \"#{uri}\""
        # puts "[DEBUG] Couldn't find API response fixture, you should probably do this:\n #{cmd}"
        puts "Caching API response, running #{cmd}"
        system cmd
        real_fetch_with_redirects( options, attempts )
      end
    end
  end
end

class FlickrCache
  class << self
    alias real_request request
    def request( flickraw, type, method, params )
      fname = "flickr.#{type}.#{method}(#{params})".gsub( /\W+/, "_" )
      fixture_path = File.expand_path( File.dirname( __FILE__ ) + "/fixtures/flickr_cache/#{fname}" )
      if File.exist?( fixture_path )
        File.open( fixture_path, &:read )
      else
        response = real_request( flickraw, type, method, params )
        File.open( fixture_path, "w" ) do | f |
          f << response
          puts "Cached #{fixture_path}. Check it in to prevent this happening in the future."
        end
      end
    end
  end
end

# Change Paperclip storage from S3 to Filesystem for testing
LocalPhoto.attachment_definitions[:file].tap do | d |
  if d.nil?
    Rails.logger.warn "Missing :file attachment definition for LocalPhoto"
  elsif d[:storage] != :filesystem
    d[:storage] = :filesystem
    d[:path] = ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension"
    d[:url] = "/attachments/:class/:attachment/:id/:style/:basename.:extension"
    d[:default_url] = "/attachment_defaults/:class/:attachment/defaults/:style.png"
  end
end

# Turn on elastic indexing for certain models. We do this selectively b/c
# updating ES slows down the specs.
def enable_elastic_indexing( *args )
  classes = [args].flatten
  classes.each do | klass |
    try_and_try_again( Elasticsearch::Transport::Transport::Errors::Conflict, sleep: 0.1, tries: 20 ) do
      klass.__elasticsearch__.client.delete_by_query( index: klass.index_name, body: { query: { match_all: {} } } )
    end
    klass.send :after_save, :elastic_index!
    klass.send :after_destroy, :elastic_delete!
    klass.send :after_touch, :elastic_index!
  end
end

# Turn off elastic indexing for certain models. Make sure to do this after
# specs if you used enable_elastic_indexing
def disable_elastic_indexing( *args )
  classes = [args].flatten
  classes.each do | klass |
    klass.send :skip_callback, :save, :after, :elastic_index!
    klass.send :skip_callback, :destroy, :after, :elastic_delete!
    klass.send :skip_callback, :touch, :after, :elastic_index!
    try_and_try_again( Elasticsearch::Transport::Transport::Errors::Conflict, sleep: 0.1, tries: 20 ) do
      klass.__elasticsearch__.client.delete_by_query( index: klass.index_name, body: { query: { match_all: {} } } )
    end
  end
end

# The `test` environment doesn't commit, and we use commit hooks to update model
# data in Elasticsearch. Tests also create a ton of data that doesn't need to be
# indexed. Use this method in specs to temporarily turn the ES-related commit
# hooks into save/touch/destroy hooks so they work in specs, and clear out test
# index data
def elastic_models( *args )
  around( :each ) do | example |
    enable_elastic_indexing( *args )
    example.run
    disable_elastic_indexing( *args )
  end
end

def stub_elastic_index!( *models )
  before do
    models.flatten.each do | model |
      allow_any_instance_of( model ).to receive( :elastic_index! ).and_return true
      allow( model ).to receive( :elastic_index! ).and_return true
    end
  end
end

def make_default_site
  unless Site.any?
    Site.make!(
      name: "iNaturalist",
      preferred_site_name_short: "iNat",
      preferred_email_noreply: "no-reply@inaturalist.org"
    )
  end
  Site.default( refresh: true )
end

def enable_has_subscribers
  enable_elastic_indexing( UpdateAction )
  CONFIG.has_subscribers = :enabled
end

def disable_has_subscribers
  disable_elastic_indexing( UpdateAction )
  CONFIG.has_subscribers = :disabled
end

def enable_user_email_domain_exists_validation
  CONFIG.user_email_domain_exists_validation = :enabled
end

def disable_user_email_domain_exists_validation
  CONFIG.user_email_domain_exists_validation = :disabled
end

def load_time_zone_geometries
  puts "load_time_zone_geometries"
  fixtures_path = File.join( Rails.root, "spec", "fixtures" )
  # Fetch data from this URL. It's not great to have this external dependency,
  # but the alternative is having a rather large fixture checked in
  url = "https://github.com/evansiroky/timezone-boundary-builder/releases/download/2020d/timezones-with-oceans.shapefile.zip"
  zip_fname = File.basename( url )
  shp_fname = "combined-shapefile-with-oceans.shp"
  puts "checking if #{File.join( fixtures_path, shp_fname )} exists"
  if File.exists?( File.join( fixtures_path, shp_fname ) )
    puts "#{shp_fname} exists, skipping download"
  else
    puts "Downloading #{url}"
    system "cd #{fixtures_path} && curl -L -s -o #{zip_fname} #{url}", exception: true
    system "cd #{fixtures_path} && unzip -o #{zip_fname}", exception: true
  end
  TimeZoneGeometry.load_shapefile( File.join( fixtures_path, shp_fname ), logger: Logger.new( $stdout ) )
end

def unload_time_zone_geometries
  TimeZoneGeometry.delete_all
end
