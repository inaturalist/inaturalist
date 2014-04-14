# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.

config = YAML.load(File.open("#{Rails.root}/config/config.yml"))
Inaturalist::Application.config.secret_token = config[Rails.env]['rails']['secret']
