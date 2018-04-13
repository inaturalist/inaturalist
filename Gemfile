source 'http://rubygems.org'

gem 'rails', "~> 4.2.7.1"

gem 'apipie-rails'
gem 'aasm'
gem 'actionpack-action_caching'
gem 'actionpack-page_caching'
gem 'activerecord-session_store'
gem 'acts-as-taggable-on', '~> 3.4'
gem 'acts_as_votable', '~> 0.10.0'
gem 'addressable', :require => 'addressable/uri'
gem 'airbrake'
gem 'ancestry'
gem 'angular-rails-templates', git: "https://github.com/gaslight/angular-rails4-templates", ref: 'v0.1.5'
# aws-sdk locked to pre 3.0; see https://github.com/thoughtbot/paperclip/issues/2484
gem 'aws-sdk', '< 3.0'
gem 'biodiversity'
gem 'bluecloth'
gem 'bugguide', git: 'https://github.com/kueda/bugguide.git'
gem 'capistrano3-delayed-job', '~> 1.0'
gem 'capistrano', '~> 3.3'
gem 'capistrano-rvm', '~> 0.1'
gem 'capistrano-rails', '~> 1.1'
gem 'capistrano-passenger', '~> 0.0'
gem 'chroma'
gem 'chronic'
gem 'coffee-rails'
gem 'cocoon' # JY: Added to support nested attributes for assessment_sections on assessments
gem 'daemons'
gem 'daemon-spawn'
gem 'dbf'
gem 'delayed_job', '~> 4.0.1'
gem 'delayed_job_active_record',
  git: 'https://github.com/hugueslamy/delayed_job_active_record.git',
  ref: '7dcacc2459ad47c948153cc3bab78bc822191718'
gem 'devise'
gem 'devise-encryptable'
gem 'devise-i18n'
gem 'devise_suspendable'
gem 'diffy'
gem 'doorkeeper', "~> 4.2.0"
gem 'dynamic_form'
gem 'exifr'
gem 'fastimage'
gem 'flickraw', "~> 0.9.8", :git => 'https://github.com/kueda/flickraw.git', :branch => 'ssl-cert'
gem "friendly_id", "~> 5.1.0"
gem 'gdata', :git => 'https://github.com/pleary/gdata.git'
gem 'geocoder'
gem 'geoplanet'
gem 'google-api-client', "=0.8.6"
gem 'georuby', :git => 'https://github.com/kueda/georuby.git'
gem 'haml'
gem 'htmlentities'
gem 'icalendar', :require => ['icalendar', 'icalendar/tzinfo']
gem 'i18n-inflector-rails'
gem 'i18n-js', :git => 'https://github.com/fnando/i18n-js.git'
gem 'irwi', :git => 'https://github.com/Programatica/irwi.git'
gem 'json'
gem 'jquery-rails', "~> 4.0.4"
gem 'koala'
gem 'dalli'
gem 'mocha', :require => false
gem "nokogiri", "~> 1.8.1"
gem "non-stupid-digest-assets"
gem "omniauth"
gem "omniauth-oauth2", " 1.3.1"
gem 'omniauth-facebook', '~> 4.0.0'
gem 'omniauth-flickr'
gem 'omniauth-openid'
gem "omniauth-google-oauth2", "~> 0.4.1"
gem 'omniauth-soundcloud', git: "https://github.com/ratafire/omniauth-soundcloud.git"
gem 'omniauth-twitter'
gem 'objectify-xml', :require => 'objectify_xml'
gem "paperclip", "~> 5.2.1"
gem 'pg'
gem 'preferences', :git => 'https://github.com/kueda/preferences.git'
gem 'rack-google-analytics', :git => 'https://github.com/kueda/rack-google-analytics.git', :branch => 'eval-blocks-per-request'
gem "rack-mobile-detect"
gem 'rails-observers'
gem 'rakismet'
gem 'rest-client', :require => 'rest_client'
gem 'rinku', :require => 'rails_rinku'
gem 'riparian', :git => 'https://github.com/inaturalist/riparian.git'
gem 'savon'   #allow to consume soap services with WSDL
gem 'sass', '= 3.2.5'
gem 'sass-rails', '=5.0.1'
gem 'soundcloud'
gem 'sprockets', '~> 2.8'
gem 'translate-rails3', :require => 'translate', :git => 'https://github.com/JayTeeSF/translate.git'
gem 'trollop'
gem 'uglifier'
gem 'utf8-cleaner'
gem "watu_table_builder", :require => "table_builder"
gem 'wicked_pdf'
gem 'will_paginate'
gem 'whenever', :require => false
gem 'ya2yaml'
gem 'yui-compressor'
gem 'xmp', "~> 0.2.1", git: 'https://github.com/kueda/xmp.git'
gem 'statsd-ruby', :require => 'statsd'
# these need to be loaded after will_paginate
gem 'elasticsearch-model', git: 'https://github.com/elasticsearch/elasticsearch-rails.git'
gem 'elasticsearch-rails', git: 'https://github.com/elasticsearch/elasticsearch-rails.git'
gem 'elasticsearch', '~> 5.0'
gem 'elasticsearch-api', '~> 5.0'

gem 'rgeo'
gem 'rgeo-geojson'
gem 'activerecord-postgis-adapter', :git => 'https://github.com/kueda/activerecord-postgis-adapter.git', :branch => 'activerecord42'

group :production do
  gem 'newrelic_rpm', '~> 3.15.0'
end

group :test, :development, :prod_dev do
  gem "database_cleaner"
  gem "machinist"
  gem "better_errors"
  gem "byebug"
  gem "binding_of_caller"
  gem 'thin', '~> 1.6.3'
  gem 'capybara', '~> 2.4'
  gem 'puma'
end

group :test do
  gem 'faker'
  gem 'simplecov', :require => false
  gem "rspec", "~> 3.4.0"
  gem "rspec-rails", "~> 3.4.2"
  gem "rspec-html-matchers"
  gem "webmock"
end
