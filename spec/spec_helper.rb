require 'simplecov'
SimpleCov.start

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] = 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'mocha/setup'
require File.expand_path(File.dirname(__FILE__) + "/blueprints")
require File.expand_path(File.dirname(__FILE__) + "/helpers/make_helpers")
require File.expand_path(File.dirname(__FILE__) + "/helpers/example_helpers")
require File.expand_path(File.dirname(__FILE__) + "/../lib/eol_service.rb")

include MakeHelpers

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
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

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction #, {:except => %w[spatial_ref_sys]}
    DatabaseCleaner.clean_with(:truncation, {:except => %w[spatial_ref_sys]})
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.before(:each) do
    Delayed::Job.delete_all
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
  
  config.before(:all) do
    [PlaceGeometry, Observation, TaxonRange].each do |klass|
      begin
        Rails.logger.debug "[DEBUG] dropping enforce_srid_geom on place_geometries"
        ActiveRecord::Base.connection.execute("ALTER TABLE #{klass.table_name} DROP CONSTRAINT IF EXISTS enforce_srid_geom")
      rescue ActiveRecord::StatementInvalid 
        # already dropped
      end
      # ensure spatial_ref_sys has a vanilla WGS84 "projection"
      begin
        ActiveRecord::Base.connection.execute(<<-SQL
          INSERT INTO spatial_ref_sys VALUES (4326,'EPSG',4326,'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4326"]]', '+proj=longlat +datum=WGS84 +no_defs')
        SQL
        )
      rescue PG::Error, ActiveRecord::RecordNotUnique => e
        raise e unless e.message =~ /duplicate key/
      end
    end
  end

  config.include Devise::TestHelpers, :type => :controller
  config.fixture_path = "#{::Rails.root}/spec/fixtures/"
  config.infer_spec_type_from_file_location!
end

def without_delay
  Delayed::Worker.delay_jobs = false
  r = yield
  Delayed::Worker.delay_jobs = true
  r
end

# http://stackoverflow.com/questions/3768718/rails-rspec-make-tests-to-pass-with-http-basic-authentication
def http_login(user)
  request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(
    user.login, "monkey")
end

# inject a fixture check into CoL service wrapper.  Need to stop making HTTP requests in tests
class EolService
  alias :real_request :request
  def request(method, *args)
    uri = get_uri(method, *args)
    fname = "#{uri.path}_#{uri.query}".gsub(/[\/\.]+/, '_')
    fixture_path = File.expand_path(File.dirname(__FILE__) + "/fixtures/eol_service/#{fname}")
    if File.exists?(fixture_path)
      Rails.logger.debug "[DEBUG] Loading cached EOL response for #{uri}: #{fixture_path}"
      Nokogiri::XML(open(fixture_path))
    else
      puts "[DEBUG] Couldn't find EOL response fixture, you should probably do this:\n wget -O \"#{fixture_path}\" \"#{uri}\""
      real_request(method, *args)
    end
  end
end

# Change Paperclip storage from S3 to Filesystem for testing
LocalPhoto.attachment_definitions[:file].tap do |d|
  if d.nil?
    Rails.logger.warn "Missing :file attachment definition for LocalPhoto"
  elsif d[:storage] != :filesystem
    d[:storage] = :filesystem
    d[:path] = ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension"
    d[:url] = "/attachments/:class/:attachment/:id/:style/:basename.:extension"
    d[:default_url] = "/attachment_defaults/:class/:attachment/defaults/:style.png"
  end
end

def stub_config(options = {})
  InatConfig.instance_eval do
    options.each do |k,v|
      define_method k do
        @config[k] ||= v
        method_missing k.to_sym
      end
    end
  end
end
