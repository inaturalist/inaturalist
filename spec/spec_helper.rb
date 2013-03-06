# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require File.expand_path(File.dirname(__FILE__) + "/blueprints")
require File.expand_path(File.dirname(__FILE__) + "/helpers/make_helpers")

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
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
  
  config.before(:all) do
    [PlaceGeometry, Observation, TaxonRange].each do |klass|
      begin
        Rails.logger.debug "[DEBUG] dropping enforce_srid_geom on place_geometries"
        ActiveRecord::Base.connection.execute("ALTER TABLE #{klass.table_name} DROP CONSTRAINT enforce_srid_geom")
      rescue ActiveRecord::StatementInvalid 
        # already dropped
      end
    end
  end

  config.include Devise::TestHelpers, :type => :controller

end

def without_delay
  Delayed::Worker.delay_jobs = false
  r = yield
  Delayed::Worker.delay_jobs = true
  r
end
