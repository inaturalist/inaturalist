module PlacesHelper
  def place_name_and_type(place, options = {})
    place_name = options[:display] ? place.display_name : place.name
    place_type_name = place_type(place)
    content_tag(:span, :class => "place #{place.place_type_name}") do
      place_name + (place_type_name.blank? ? '' : " #{place_type_name}")
    end
  end
  
  def place_type(place)
    place_type_name = nil
    place_type_name = if place.place_type
      content_tag(:span, :class => 'place_type description') do
        "(#{place.place_type_name})"
      end
    end
    place_type_name
  end
  
  def google_static_map_for_place(place, options = {}, tag_options = {})
    url_for_options = {
      :host => 'maps.google.com',
      :controller => 'maps/api/staticmap',
      :center => "#{place.latitude},#{place.longitude}",
      :zoom => 15,
      :size => '200x200',
      :sensor => 'false',
      :key => Ym4r::GmPlugin::ApiKey.get
    }.merge(options)
    
    tag_options[:alt] ||= "Google Map for #{place.display_name}"
    tag_options[:width] ||= url_for_options[:size].split('x').first
    tag_options[:height] ||= url_for_options[:size].split('x').last
    
    image_tag(
      url_for(url_for_options),
      tag_options
    )
  end
  
  # Returns GMaps zoom level for a place given map dimensions in pixels
  def map_zoom_for_place(place, width, height)
    return 0 if [place.nelat, place.nelng, place.swlat, place.swlng].include?(nil)
    (1..SPHERICAL_MERCATOR.levels).reverse_each do |zoom_level|
      minx, miny = SPHERICAL_MERCATOR.from_ll_to_pixel([place.swlng, place.swlat], zoom_level)
      maxx, maxy = SPHERICAL_MERCATOR.from_ll_to_pixel([place.nelng, place.nelat], zoom_level)
      return zoom_level if (maxx - minx < width) && (maxy - miny < height)
    end
  end
end
