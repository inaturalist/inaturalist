xml.Placemark(:id => "ID#{observation.id}") do
  xml.name observation.species_guess
  xml.visibility "1"
  
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
  
  # if observation.taxon && observation.taxon.iconic_taxon
  if observation.iconic_taxon
    xml.styleUrl(
      url_for(:controller => '/', :only_path=>false) +
      "stylesheets/observations/google_earth.kml" +
      @prevent_cache + "#" +observation.iconic_taxon.name
    )
  else
    xml.styleUrl(
      url_for(:controller => '/', :only_path=>false) +
      "stylesheets/observations/google_earth.kml" +
      @prevent_cache +"#Unknown"
    )
  end

  if observation.latitude && observation.longitude
    xml.Point do
      xml.coordinates("#{observation.longitude},#{observation.latitude}")
    end
  end
end