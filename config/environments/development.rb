# Settings specified here will take precedence over those in config/environment.rb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_view.debug_rjs                         = true

# Caching
config.action_controller.perform_caching             = false
config.action_view.cache_template_loading            = false

# # Uncomment these to test caching
# # config.cache_store = :file_store, RAILS_ROOT + "/tmp/cache"
config.cache_store = :mem_cache_store, INAT_CONFIG["memcached"]
# config.action_controller.perform_caching             = true
# config.action_view.cache_template_loading            = true
# config.cache_classes = true

# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = true
config.action_mailer.default_url_options = { :host => 'localhost:3000' }
smtp_config_path = File.open("#{RAILS_ROOT}/config/smtp.yml")
ActionMailer::Base.smtp_settings = YAML.load(smtp_config_path)
config.action_mailer.delivery_method = :test

require 'ruby-debug'
require 'activerecord_reset_subclass_fix'

config.middleware.use MailView::Mapper, [EmailerPreview]
