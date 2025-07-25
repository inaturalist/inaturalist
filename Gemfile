# frozen_string_literal: true

source "https://rubygems.org"

ruby "~> 3.3.7"

gem "rails", "6.1.7.9"

gem "actionpack-action_caching"
gem "actionpack-page_caching"
gem "activerecord-postgis-adapter"
gem "activerecord-session_store"
gem "acts-as-taggable-on"
gem "acts_as_votable"
gem "ancestry"
gem "angular-rails-templates"
gem "audited"
gem "aws-sdk-cloudfront"
gem "aws-sdk-s3"
gem "aws-sdk-waf"
gem "aws-sdk-wafv2"
gem "bower-rails"
gem "bundler-audit"
gem "capistrano"
gem "capistrano-passenger"
gem "capistrano-rails"
gem "capistrano-rvm"
gem "chroma"

# DST crossover fixes: https://github.com/mojombo/chronic/pull/396
gem "chronic", git: "https://github.com/stanhu/chronic.git", ref: "7ea371f"
gem "cocoon" # JY: Added to support nested attributes for assessment_sections on assessments
# gem "coffee-rails"
gem "concurrent-ruby", "1.3.4"
gem "daemons"
gem "dalli"
gem "dbf" # Needed for georuby shapefile support
gem "delayed_job"
gem "delayed_job_active_record"
gem "devise"
gem "devise-encryptable"
gem "devise-i18n"
gem "devise_suspendable"
gem "diffy"
gem "dm_preferences", git: "https://github.com/inaturalist/preferences.git", ref: "inat-patches"
gem "doorkeeper"
gem "dynamic_form", git: "https://github.com/GoodMeasuresLLC/dynamic_form.git"
gem "elasticsearch", "~> 8"
gem "elasticsearch-api", "~> 8"
gem "elasticsearch-model", "~> 8"
gem "elasticsearch-rails", "8.0.0.pre"
gem "email_address"
gem "exifr", require: ["exifr", "exifr/jpeg", "exifr/tiff"]
gem "exiftool_vendored" # Vendored version includes exiftool and exiftool gem
gem "fastimage"
gem "flickr"
gem "friendly_id"
gem "georuby"
gem "haml"
gem "htmlentities"
gem "i18n-inflector-rails", git: "https://github.com/siefca/i18n-inflector-rails.git",
  ref: "99726dc44e166f6fb794caec9d3244795e7ee79b"
gem "i18n-js", git: "https://github.com/fnando/i18n-js.git", tag: "v3.7.0"
gem "icalendar", require: ["icalendar", "icalendar/tzinfo"]
gem "irwi", git: "https://github.com/inaturalist/irwi.git", ref: "ruby3"
gem "json"
gem "makara", git: "https://github.com/instacart/makara.git", ref: "9e7960558a75aed3f97ba4cbab61abb64687ec3c"
gem "multi_json", "~> 1.15.0"
gem "nokogiri"
gem "non-stupid-digest-assets"
gem "objectify-xml", git: "https://github.com/inaturalist/objectify_xml.git"
gem "omniauth"
gem "omniauth-apple"
gem "omniauth-flickr", git: "https://github.com/pleary/omniauth-flickr.git",
  ref: "fdfd81f47c33a21953ad97e0b5e2749b89989ef0"
gem "omniauth-google-oauth2"
gem "omniauth-oauth2"
gem "omniauth-openid"
gem "omniauth-orcid"
gem "omniauth-rails_csrf_protection"
gem "omniauth-soundcloud", git: "https://github.com/ratafire/omniauth-soundcloud.git"
gem "omniauth-twitter"
gem "optimist"
gem "kt-paperclip", git: "https://github.com/inaturalist/kt-paperclip.git", ref: "reset-original-content-type"
gem "parallel"
gem "patron"
gem "pg", "~> 1.5.9"
gem "rqrcode", "~> 2.0"
gem "rack-cors"
gem "rack-mobile-detect"
gem "rack-tracker"
gem "rails-controller-testing"
gem "rails-html-sanitizer"
gem "rails-i18n"
gem "rails-observers"
gem "rakismet"
gem "rdoc", "< 6.4.0"
gem "redcarpet"
gem "rest-client", require: "rest_client"
gem "rexml"
gem "rgeo"
gem "rgeo-geojson"
gem "rgeo-proj4", "~> 3.1.1"
gem "rgeo-shapefile"
gem "rinku", "~> 2.0"
gem "riparian", git: "https://github.com/inaturalist/riparian.git", ref: "rails6"
gem "rubyzip", "~> 2.3.0"
gem "sass-rails"
gem "savon" # allow to consume soap services with WSDL
gem "soundcloud"
gem "sprockets"
gem "terrapin"
gem "terser"
gem "utf8-cleaner"
gem "watu_table_builder", require: "table_builder"
gem "whenever", require: false
gem "will_paginate"
gem "xmp", git: "https://github.com/inaturalist/xmp.git"
gem "ya2yaml"
gem "yajl-ruby", require: "yajl"
gem "yui-compressor"

group :production do
  gem "newrelic_rpm"
end

group :test, :development, :prod_dev do
  gem "database_cleaner"

  # this fork fixes the `warning: constant ::Fixnum is deprecated` warnings
  # See https://github.com/notahat/machinist/pull/133
  gem "machinist", git: "https://github.com/narze/machinist", ref: "eaf5a447ff0d59a1fb2c49b91c6e1b2d95d8e4ee"

  gem "better_errors"
  gem "binding_of_caller"
  gem "byebug"
  gem "capybara"
  gem "lefthook", require: false
  gem "puma"
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
end

group :development do
  # The following are required for ed25519 ssh keys
  gem "ed25519"
  gem "bcrypt_pbkdf"
end

group :test do
  gem "factory_bot_rails", require: false
  gem "faker"
  gem "rspec"
  gem "rspec-html-matchers"
  gem "rspec-rails"
  gem "shoulda-matchers"
  gem "simplecov", require: false
  gem "webmock"
  gem "vcr"
end
