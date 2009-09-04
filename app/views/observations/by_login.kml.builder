xml.instruct!
@prevent_cache = "?prevent=#{rand(1024)}"

xml.kml "xmlns" => "http://www.opengis.net/kml/2.2" do
  
  xml.NetworkLinkControl do
        
    xml.minRefreshPeriod("3600")
    xml.linkName(@net_hash[:name])
    xml.linkDescription(@net_hash[:description])
    xml.linkSnippet(@net_hash[:snippet], :maxLines=>"2")
    
  end
  
  xml.Document do  
    @observations.each do |observation|
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
            render(
              :layout => 'observations/mini', 
              :locals => { :observation => observation, 
                           :description_length => 80 }
            )
          )
        end
        
        if observation.taxon && observation.taxon.iconic_taxon
          xml.styleUrl(
            url_for(:controller => '/', :only_path=>false) + 
            "stylesheets/observations/google_earth.kml" + 
            @prevent_cache + 
            "#" + observation.taxon.iconic_taxon.name
          )
        else
          xml.styleUrl(
            url_for(:controller => '/', :only_path=>false) + 
            "stylesheets/observations/google_earth.kml" + 
            @prevent_cache + "#Unknown"
          )
        end
        
        if observation.latitude && observation.longitude
          xml.Point do
            xml.coordinates("#{observation.longitude},#{observation.latitude}")
          end
        end
      end
    end 
  end
end
