xml.Placemark(:id => "ID#{observation.id}") do
  xml.name observation.species_guess
  xml.visibility "1"
  xml.atom(:link, observation_url(observation))
  
  if observation.observed_on
    xml.TimeStamp do
      xml.when(observation.observed_on.strftime("%Y-%m-%dT%H:%M:%SZ"))
    end
  end
  
  xml.description do
    xml.cdata!(
      render_in_format :html, :partial => "mini", :object => observation, :locals => {
        :image_size => "small"
      }
    )
  end
  
  xml.styleUrl(
    "#{root_url}stylesheets/observations/google_earth.kml#{@prevent_cache}" +
      "##{observation.iconic_taxon.try(:name) || 'Unknown'}"
  )

  if observation.latitude && observation.longitude
    xml.Point do
      xml.coordinates("#{observation.longitude},#{observation.latitude}")
    end
  end
end
