Rails.application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  # The test environment is used exclusively to run your application's
  # test suite.  You never need to work with it otherwise.  Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs.  Don't rely on the data there!
  config.cache_classes = true

  # Normally the test env autoloads lazily (false) for fast RSpec boots. But the
  # e2e suite boots a live, multi-threaded Puma (`rails server -e test`), and this
  # app still uses the classic autoloader (`config.load_defaults 5.0`), which is
  # NOT thread-safe. Concurrent requests then race while synthesizing implicit
  # namespace modules like `Users` (which spans app/controllers/users,
  # app/webpack/users, ...), producing "already initialized constant Users" and
  # "Unable to autoload constant Users::SessionsController" LoadErrors. Eager
  # loading at boot (single-threaded) loads every constant before any request, so
  # no thread ever autoloads at request time. Enabled only for the e2e server.
  config.eager_load = ENV["E2E_EAGER_LOAD"] == "true"

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :memory_store

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection    = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test
  # config.action_mailer.default_url_options = "localhost:3000" : URI.parse(CONFIG.site_url).host }

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr
end
