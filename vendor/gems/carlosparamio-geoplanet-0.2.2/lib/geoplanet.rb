%w{rubygems rest_client}.each { |x| require x }

if defined?(ActiveSupport::JSON)
  JSON = ActiveSupport::JSON
  module JSON
    def self.parse(json)
      decode(json)
    end
  end
else
  require 'json'
end

require 'geoplanet/version'
require 'geoplanet/base'
require 'geoplanet/place'

module GeoPlanet
  API_VERSION = "v1"
  API_URL     = "http://where.yahooapis.com/#{API_VERSION}/"
    
  class << self
    attr_accessor :appid, :debug
  end

  class BadRequest           < StandardError; end
  class NotFound             < StandardError; end
  class NotAcceptable        < StandardError; end
end
