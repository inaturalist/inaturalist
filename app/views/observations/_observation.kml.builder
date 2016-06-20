styleUrl = asset_path("observations/google_earth.kml")
styleUrl += @prevent_cache if @prevent_cache
styleUrl += '#'
styleUrl += observation.iconic_taxon_id ? Taxon::ICONIC_TAXA_BY_ID[observation.iconic_taxon_id].try(:name).to_s : 'Unknown'
styleUrl += "Stemless" if observation.coordinates_obscured?
xml.Placemark(:id => "ID#{observation.id}") do
  xml.name observation.species_guess
  xml.visibility "1"
  xml.atom(:link, observation_url(observation))
  
  if observation.datetime
    xml.TimeStamp do
      xml.when( observation.datetime.strftime( observation.time_observed_at ? "%Y-%m-%dT%H:%M:%SZ%:z" : "%Y-%m-%d" ) )
    end
  end
  
  xml.description do
    xml.cdata!(
      render_in_format :html, :partial => "plain", :object => observation, :locals => {
        :image_size => "thumb",
        :hide_species_guess => true
      }
    )
  end
  
  xml.styleUrl styleUrl

  if observation.latitude && observation.longitude
    xml.Point do
      xml.coordinates("#{observation.longitude},#{observation.latitude}")
    end
  end
end
