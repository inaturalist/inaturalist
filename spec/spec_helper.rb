# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require File.expand_path(File.dirname(__FILE__) + "/blueprints")
require File.expand_path(File.dirname(__FILE__) + "/helpers/make_helpers")

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
    begin
      ActiveRecord::Base.connection.execute("ALTER TABLE place_geometries DROP CONSTRAINT enforce_srid_geom")
    rescue ActiveRecord::StatementInvalid 
      # already dropped
    end
    begin
      ActiveRecord::Base.connection.execute("ALTER TABLE observations DROP CONSTRAINT enforce_srid_geom")
    rescue ActiveRecord::StatementInvalid 
      # already dropped
    end
  end

end

def without_delay
  Delayed::Worker.delay_jobs = false
  yield
  Delayed::Worker.delay_jobs = true
end
