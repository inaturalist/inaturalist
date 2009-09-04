require 'rubaidh/google_analytics'
ActionController::Base.send :include, Rubaidh::GoogleAnalyticsMixin
ActionController::Base.send :after_filter, :add_google_analytics_code