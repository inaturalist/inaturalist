source 'http://rubygems.org'

gem 'rails', "~> 4.2.6"

gem 'apipie-rails'
gem 'aasm'
gem 'actionpack-action_caching'
gem 'actionpack-page_caching'
gem 'acts-as-taggable-on', '~> 3.4'
gem 'acts_as_votable', '~> 0.10.0'
gem 'addressable', :require => 'addressable/uri'
gem 'airbrake'
gem 'ancestry'
gem 'angular-rails-templates', git: "git://github.com/gaslight/angular-rails4-templates", ref: 'v0.1.5'
gem 'aws-sdk'
gem 'biodiversity'
gem 'bluecloth'
gem 'bugguide', git: 'git://github.com/kueda/bugguide.git'
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
gem 'delayed_job_active_record', '~> 4.0.1'
gem 'devise'
gem 'devise-encryptable'
gem 'devise-i18n'
gem 'devise_suspendable'
gem 'diffy'
gem 'doorkeeper'
gem 'dynamic_form'
gem 'exifr'
gem 'fastimage'
gem 'flickraw', "~> 0.9.8", :git => 'git://github.com/kueda/flickraw.git', :branch => 'ssl-cert'
gem "friendly_id", "~> 5.1.0"
gem 'gdata', :git => 'git://github.com/pleary/gdata.git'
gem 'geocoder'
gem 'geoplanet'
gem 'google-api-client'
gem 'georuby', :git => 'git://github.com/kueda/georuby.git'
gem 'haml'
gem 'htmlentities'
gem 'icalendar', :require => ['icalendar', 'icalendar/tzinfo']
gem 'i18n-inflector-rails'
gem 'i18n-js', :git => 'git://github.com/fnando/i18n-js.git'
gem 'irwi', :git => 'git://github.com/Programatica/irwi.git'
gem 'json'
gem 'jquery-rails'
gem 'koala'
gem 'dalli'
gem 'mocha', :require => false
gem 'mobile-fu', :git => 'https://github.com/kueda/mobile-fu.git'
gem 'nokogiri'
gem "non-stupid-digest-assets"
gem 'omniauth-facebook'
gem 'omniauth-flickr'
gem 'omniauth-openid'
gem "omniauth-google-oauth2"
gem 'omniauth-soundcloud'
gem 'omniauth-twitter'
gem 'objectify-xml', :require => 'objectify_xml'
gem "paperclip", "4.2.1"
gem 'delayed_paperclip', :git => 'git://github.com/jrgifford/delayed_paperclip.git'
gem 'pg'
gem 'preferences', :git => 'git://github.com/kueda/preferences.git'
gem 'rack-google-analytics', :git => 'git://github.com/kueda/rack-google-analytics.git', :branch => 'eval-blocks-per-request'
gem 'rails-observers'
gem 'rakismet'
gem 'RedCloth'
gem 'rest-client', :require => 'rest_client'
gem 'right_aws', :git => 'git://github.com/rightscale/right_aws.git'
gem 'right_http_connection'
gem 'rinku', :require => 'rails_rinku'
gem 'riparian', :git => 'git://github.com/inaturalist/riparian.git'
gem 'savon'   #allow to consume soap services with WSDL
gem 'sass', '= 3.2.5'
gem 'sass-rails', '=5.0.1'
gem 'soundcloud'
gem 'sprockets', '~> 2.8'
gem 'translate-rails3', :require => 'translate', :git => 'git://github.com/JayTeeSF/translate.git'
gem 'trollop'
gem 'twitter'
gem 'uglifier'
gem 'useragent'
gem 'utf8-cleaner'
gem "watu_table_builder", :require => "table_builder"
gem 'wicked_pdf'
gem 'will_paginate'
gem 'whenever', :require => false
gem 'ya2yaml'
gem 'yui-compressor'
gem 'xmp', :git => 'git://github.com/kueda/xmp.git'
gem 'statsd-ruby', :require => 'statsd'
# these need to be loaded after will_paginate
gem 'elasticsearch-model', git: 'git://github.com/elasticsearch/elasticsearch-rails.git'
gem 'elasticsearch-rails', git: 'git://github.com/elasticsearch/elasticsearch-rails.git'

gem 'rgeo'
gem 'rgeo-geojson'
gem 'activerecord-postgis-adapter', :git => 'git://github.com/kueda/activerecord-postgis-adapter.git', :branch => 'activerecord42'

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
end

group :test do
  gem 'faker'
  gem 'simplecov', :require => false
  gem "rspec", "~> 3.4.0"
  gem "rspec-rails", "~> 3.4.2"
  gem "rspec-html-matchers"
  gem 'cucumber-rails', require: false
  gem 'selenium-webdriver'
  gem "chromedriver-helper"
end
