module GeoPlanet
  class Place < Base
    attr_reader  :version # short or long
    # short
    attr_reader  :woeid, :placetype, :placetype_code, :name, :uri, :lang
    # long
    attr_reader  :country, :country_code, :postal
    attr_reader  :latitude, :longitude, :bounding_box
    attr_reader  :admin1, :admin1_code, :admin1_placetype
    attr_reader  :admin2, :admin2_code, :admin2_placetype
    attr_reader  :admin3, :admin3_code, :admin3_placetype
    attr_reader  :locality1, :locality1_placetype
    attr_reader  :locality2, :locality2_placetype
    alias_method :lat, :latitude 
    alias_method :lon, :longitude

    # Class methods
    def self.search(text, options = {})
      text = URI.encode(text)
      url = build_url('places', options.merge(:q => text, :format => 'json'))
      puts "Yahoo GeoPlanet: GET #{url}" if GeoPlanet.debug
      get_then_parse(url)
    end
    
    def self.get_then_parse(url)
      results = JSON.parse get(url)
      return results['places']['place'].map{|attrs| Place.new attrs} if results['places']
      return Place.new(results['place']) if results['place']
      nil
    rescue
      nil
    end

    %w(parent ancestors belongtos neighbors siblings children).each do |association|
      self.instance_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{association}_of(woeid, options = {})
          url = build_url("place/\#{woeid}/#{association}", options.merge(:format => "json"))
          puts "Yahoo GeoPlanet: GET \#{url}" if GeoPlanet.debug
          get_then_parse(url)
        end
      RUBY
    end
    
    # Instance methods
    def initialize(woe_or_attrs, options = {})
      case woe_or_attrs
      when Integer then initialize_with_woe(woe_or_attrs, options)
      when Hash    then initialize_with_attrs(woe_or_attrs)
      else
        raise ArgumentError
      end
    end
    
    def initialize_with_woe(woe, options = {})
      url = self.class.build_url("place/#{woe}", options.merge(:format => "json"))
      puts "Yahoo GeoPlanet: GET #{url}" if GeoPlanet.debug
      initialize_with_attrs JSON.parse(Place.get(url))['place']
    end
    
    
    def initialize_with_attrs(attrs)
      @version = attrs['centroid'] ? 'long' : 'short'

      # short
      @woeid          = attrs['woeid']
      @placetype      = attrs['placeTypeName']
      @placetype_code = attrs['placeTypeName attrs']['code']
      @name           = attrs['name']
      @uri            = attrs['uri']
      @lang           = attrs['lang']

      if version == 'long'
        # long
        @latitude            = attrs['centroid']['latitude']
        @longitude           = attrs['centroid']['longitude']
        @bounding_box        = [ [ attrs['boundingBox']['southWest']['latitude'],
                                   attrs['boundingBox']['southWest']['longitude'] ],
                                 [ attrs['boundingBox']['northEast']['latitude'],
                                   attrs['boundingBox']['northEast']['longitude'] ],
                               ]
        @country             = attrs['country']
        @country_code        = attrs['country attrs']['code']   rescue nil
        @postal              = attrs['postal']
        @admin1              = attrs['admin1']
        @admin1_code         = attrs['admin1 attrs']['code']    rescue nil
        @admin1_placetype    = attrs['admin1 attrs']['type']    rescue nil
        @admin2              = attrs['admin2']
        @admin2_code         = attrs['admin2 attrs']['code']    rescue nil
        @admin2_placetype    = attrs['admin2 attrs']['type']    rescue nil
        @admin3              = attrs['admin3']
        @admin3_code         = attrs['admin3 attrs']['code']    rescue nil
        @admin3_placetype    = attrs['admin3 attrs']['type']    rescue nil
        @locality1           = attrs['locality1']
        @locality1_placetype = attrs['locality1 attrs']['type'] rescue nil
        @locality2           = attrs['locality2']
        @locality2_placetype = attrs['locality2 attrs']['type'] rescue nil
      end
      self
    end

    # Association Collections
    %w(parent ancestors belongtos neighbors siblings children).each do |association|
      self.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{association}(options = {})
          Place.send("#{association}_of", self.woeid, options)
        end
      RUBY
    end
    
    def to_s
      self.name
    end
    
    def to_i
      self.woeid.to_i
    end
    
  end
end