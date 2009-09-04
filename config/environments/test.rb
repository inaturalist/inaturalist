# Settings specified here will take precedence over those in config/environment.rb

configuration_bindings = YAML.load(File.open("#{RAILS_ROOT}/config/config.yml"))

# The test environment is used exclusively to run your application's
# test suite.  You never need to work with it otherwise.  Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs.  Don't rely on the data there!
config.cache_classes = true

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching = false

# Tell ActionMailer not to deliver emails to the real world.
# The :test delivery method accumulates sent emails in the
# ActionMailer::Base.deliveries array.
config.action_mailer.delivery_method = :test

# Disable request forgery protection in test environment
config.action_controller.allow_forgery_protection = false

# flickr api keys
FLICKR_API_KEY = configuration_bindings['test']['flickr']['FLICKR_API_KEY']
FLICKR_SHARED_SECRET = configuration_bindings['test']['flickr']['FLICKR_SHARED_SECRET']
