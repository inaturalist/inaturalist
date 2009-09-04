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
      :controller => 'staticmap',
      :center => "#{place.latitude},#{place.longitude}",
      :zoom => 15,
      :size => '200x200',
      :sensor => false,
      :key => Ym4r::GmPlugin::ApiKey.get
    }.merge(options)
    
    image_tag(
      url_for(url_for_options),
      tag_options
    )
  end
end
