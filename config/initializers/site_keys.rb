# SENSITIVE
# See vendor/plugins/restful_authentication/notes/Tradeoffs.txt for more info
configuration_bindings = YAML.load(File.open("#{Rails.root}/config/config.yml"))
REST_AUTH_SITE_KEY         = configuration_bindings['base']['rest_auth']['REST_AUTH_SITE_KEY']
REST_AUTH_DIGEST_STRETCHES = configuration_bindings['base']['rest_auth']['REST_AUTH_DIGEST_STRETCHES']
