
source "https://rubygems.org"

ruby "~> 2.6.0"

gem "rails", "5.2.6"

gem "actionpack-action_caching"
gem "actionpack-page_caching"
gem "activerecord-session_store"
gem "acts-as-taggable-on"
gem "acts_as_votable"
gem "ancestry"
gem "angular-rails-templates"
gem "audited", "~> 5.0"
gem "aws-sdk-cloudfront"
gem "aws-sdk-s3"
gem "aws-sdk-waf"
gem "biodiversity"
gem "capistrano"
gem "capistrano-rvm"
gem "capistrano-rails"
gem "capistrano-passenger"
gem "chroma"
gem "chronic"
gem "coffee-rails"
gem "cocoon" # JY: Added to support nested attributes for assessment_sections on assessments
gem "dbf" # Needed for georuby shapefile support
gem "delayed_job" #, "~> 4.1.5"
gem "delayed_job_active_record"
gem "devise"
gem "devise-encryptable"
gem "devise-i18n"
gem "devise_suspendable"
gem "diffy"
gem "doorkeeper"
gem "dynamic_form"
gem "exifr", require: ["exifr", "exifr/jpeg", "exifr/tiff"]
gem "exiftool_vendored" # Vendored version includes exiftool and exiftool gem
gem "fastimage"
gem "flickraw-cached"
gem "friendly_id"
gem "gdata", git: "https://github.com/pleary/gdata.git"
gem "georuby"
gem "haml"
gem "htmlentities"
gem "icalendar", require: ["icalendar", "icalendar/tzinfo"]
gem "i18n-inflector-rails"
gem "i18n-js", git: "https://github.com/fnando/i18n-js.git"
gem "irwi", git: "https://github.com/Programatica/irwi.git"
gem "json"
gem "koala"
gem "dalli"
gem "nokogiri"
gem "non-stupid-digest-assets"
gem "objectify-xml", git: "https://github.com/inaturalist/objectify_xml.git"
gem "omniauth"
gem "omniauth-oauth2"
gem "omniauth-facebook"
gem "omniauth-flickr", git: "https://github.com/IDolgirev/omniauth-flickr.git", ref: "bcd202b0825659cbd984e611f6151f67c4aae591"
gem "omniauth-openid", git: "https://github.com/inaturalist/omniauth-openid"
gem "omniauth-orcid"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"
gem "omniauth-soundcloud", git: "https://github.com/ratafire/omniauth-soundcloud.git"
gem "omniauth-twitter"
gem "omniauth-apple"
gem "paperclip"
gem "optimist"
gem "patron"
gem "pg"
gem "dm_preferences", git: "https://github.com/nickcoyne/preferences.git"
gem "rack-cors"
gem "rack-mobile-detect"
gem "rack-tracker"
gem "rails-controller-testing"
gem "rails-observers"
gem "rails-html-sanitizer"
gem "rails-i18n"
gem "rakismet"
gem "redcarpet"
gem "rest-client", require: "rest_client"
gem "riparian", git: "https://github.com/inaturalist/riparian.git"
gem "savon" # allow to consume soap services with WSDL
gem "sass-rails"
gem "soundcloud"
gem "sprockets"
gem "uglifier"
gem "utf8-cleaner"
gem "watu_table_builder", require: "table_builder"
gem "will_paginate"
gem "whenever", require: false
gem "ya2yaml"
gem "yajl-ruby", require: "yajl"
gem "yui-compressor"
gem "xmp", git: "https://github.com/inaturalist/xmp.git"
gem "rubyzip"
gem "elasticsearch-model"
gem "elasticsearch-rails"
gem "elasticsearch"
gem "elasticsearch-api"
gem "rgeo"
gem "rgeo-geojson"
gem "rgeo-proj4", "~> 2.0.1"
gem "rgeo-shapefile"
gem "activerecord-postgis-adapter", ">= 5", "< 6"
gem "terrapin"

group :production do
  gem "newrelic_rpm", "~> 6.2.0"
end

group :test, :development, :prod_dev do
  gem "database_cleaner"

  # this fork fixes the `warning: constant ::Fixnum is deprecated` warnings
  # See https://github.com/notahat/machinist/pull/133
  gem "machinist", git: "https://github.com/narze/machinist", ref: "eaf5a447ff0d59a1fb2c49b91c6e1b2d95d8e4ee"

  gem "better_errors"
  gem "byebug"
  gem "binding_of_caller"
  gem "thin"
  gem "capybara"
  gem "puma"
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "lefthook", require: false
end

group :test do
  gem "factory_bot_rails", require: false
  gem "faker"
  gem "simplecov", require: false
  gem "rspec"
  gem "rspec-rails"
  gem "shoulda-matchers"
  gem "rspec-html-matchers"
  gem "webmock"
end
