require "forwardable"

module Observations
  class GuessPlaceFromLatlon
    def initialize(lat, lon, options = {})
      @lat = lat
      @lon = lon
      @options = options
    end

    def call
      sys_places = Observation.system_places_for_latlon(lat, lon, options)
      return if sys_places.blank?
      sys_places_codes = sys_places.map(&:code)
      user = options[:user]
      locale = options[:locale]
      locale ||= user.locale if user
      locale ||= I18n.locale
      first_name = if sys_places[0].admin_level == Place::COUNTY_LEVEL && sys_places_codes.include?( "US" )
        "#{sys_places[0].name} County"
      else
        I18n.t( sys_places[0].name, locale: locale, default: sys_places[0].name )
      end
      remaining_names = sys_places[1..-1].map do |p|
        if p.admin_level == Place::COUNTY_LEVEL && sys_places_codes.include?( "US" )
          "#{p.name} County"
        else
          translated_place = I18n.t(
            p.name,
            locale: locale,
            default: I18n.t(
              "places_name.#{p.name.underscore}",
              locale: locale,
              default: p.name
            )
          )
          p.code.blank? ? translated_place : p.code
        end
      end
      [first_name, remaining_names].flatten.join( ", " )
    end

    private

    attr_reader :lat, :lon, :options
  end
end
