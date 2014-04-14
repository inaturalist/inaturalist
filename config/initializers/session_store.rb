# Be sure to restart your server when you modify this file.
config = YAML.load(File.open("#{Rails.root}/config/config.yml"))
Inaturalist::Application.config.session_store :cookie_store, :key => config[Rails.env]['rails']['key']

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# Inaturalist::Application.config.session_store :active_record_store
