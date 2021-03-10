module PlacesHelper
  def place_name_and_type(place, options = {})
    place_name = if options[:display]
      place.display_name
    else
      place.translated_name
    end
    place_type_name = place_type(place)
    content_tag(:span, :class => "place #{place.place_type_name}") do
      raw(place_name + (place_type_name.blank? ? '' : " #{place_type_name}"))
    end
  end
  
  def place_type(place)
    place_type_name = nil
    place_type_name = if place.place_type
      key = "place_geo.geo_planet_place_types.#{place.place_type_name.underscore.downcase}"
      content_tag(:span, :class => 'place_type meta') do
        "(#{t(key, :default => place.place_type_name)})"
      end
    end
    place_type_name
  end
  
  def google_static_map_for_place(place, options = {}, tag_options = {})
    tag_options[:alt] ||= "Google Map for #{place.display_name}"
    tag_options[:width] ||= options[:size] ? options[:size].split('x').first : 200
    tag_options[:height] ||= options[:size] ? options[:size].split('x').last : 200
    image_tag(
      google_static_map_for_place_url(place, options),
      tag_options
    )
  end
  
  def google_static_map_for_place_url(place, options = {})
    return if CONFIG.google.blank? || CONFIG.google.browser_api_key.blank?
    url_for_options = {
      :host => 'maps.google.com',
      :controller => 'maps/api/staticmap',
      :center => "#{place.latitude},#{place.longitude}",
      :zoom => 15,
      :size => '200x200',
      :sensor => 'false',
      :port => false,
      :key => CONFIG.google.browser_api_key
    }.merge(options)
    url_for(url_for_options)
  end
  
  # Returns GMaps zoom level for a place given map dimensions in pixels
  def map_zoom_for_place(place, width, height)
    return 0 if [place.nelat, place.nelng, place.swlat, place.swlng].include?(nil)
    (1..SPHERICAL_MERCATOR.levels).to_a.reverse_each do |zoom_level|
      minx, miny = SPHERICAL_MERCATOR.from_ll_to_pixel([place.swlng, place.swlat], zoom_level)
      maxx, maxy = SPHERICAL_MERCATOR.from_ll_to_pixel([place.nelng, place.nelat], zoom_level)
      return zoom_level if (maxx - minx < width) && (maxy - miny < height)
    end
  end
  
  def google_charts_map_for_places(places, options = {}, tag_options = {})
    countries = places.select {|p| p.place_type == Place::PLACE_TYPE_CODES['Country']}
    states = places.select {|p| p.admin_level == Place::STATE_LEVEL && p.parent.try(:code) == 'US'}
    geographical_area = 'world'
    labels = countries.map(&:code)
    if states.size > 0 && (countries.empty? || (countries.size == 1 && countries.first.code = 'US'))
      labels = states.map {|s| s.code.gsub('US-', '')}
      geographical_area = 'usa'
    end
    data = "t:#{(['100'] * labels.size).join(',')}"
    url_for_options = {
      :host => 'chart.googleapis.com',
      :controller => 'chart',
      :port => nil,
      :chs => '440x220',
      :chco => 'EEEEEE,1E90FF,1E90FF',
      :chld => labels.join,
      :chd => labels.empty? ? 's:_' : data,
      :cht => 't',
      :chtm => geographical_area
    }.merge(options)
    
    tag_options[:alt] = "Map of #{geographical_area == 'usa' ? 'US states' : 'countries'}: #{labels.join(', ')}"
    tag_options[:width] ||= url_for_options[:chs].split('x').first
    tag_options[:height] ||= url_for_options[:chs].split('x').last
    
    image_tag(
      url_for(url_for_options),
      tag_options
    )
  end

  def place_geometry_kml_url(options = {})
    place = options[:place] || @place
    return '' if place.blank?
    place_geometry = options[:place_geometry]
    place_geometry ||= place.place_geometry_without_geom if place.association(:place_geometry_without_geom).loaded?
    place_geometry ||= place.place_geometry if place.association(:place_geometry).loaded?
    place_geometry ||= PlaceGeometry.without_geom.where(:place_id => place).first
    if place_geometry.blank?
      ''.html_safe
    else
      "#{place_geometry_url(place, :format => "kml")}?#{place_geometry.updated_at.to_i}".html_safe
    end
  end

  def nested_place_list(*args, &block)
    arranged = if args.first.is_a?(ActiveSupport::OrderedHash)
      args.first
    else
      candidates = args.first.is_a?(Array) ? args.first.compact.flatten : args.compact.flatten
      places = candidates if candidates.first.is_a?(Place)
      places ||= candidates.map(&:place).compact
      Place.arrange_nodes(places.sort_by{|p| p.ancestry.to_s + "#/0/{#{p.name}}"})
    end
    content_tag :ul do
      arranged.map do |place, children|
        li = if block_given?
          capture(place, &block)
        else
          link_to(place.display_name, place)
        end
        li += nested_place_list(children, &block) unless children.blank?
        content_tag :li, li
      end.join(' ').html_safe
    end.html_safe
  end
end
