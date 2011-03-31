xml.instruct!
@prevent_cache = "?prevent=#{rand(1024)}"

xml.kml "xmlns" => "http://www.opengis.net/kml/2.2", 
        "xmlns:atom" => "http://www.w3.org/2005/Atom"  do

  xml.NetworkLinkControl do

    xml.minRefreshPeriod("5")
    xml.linkName(@net_hash[:name])
    xml.linkDescription(@net_hash[:description])
    xml.linkSnippet(@net_hash[:snippet], :maxLines=>"2")

  end

  xml.Document do
    unless @observations.blank?
      sorted = @observations.reject{|o| o.observed_on.blank?}.sort_by(&:observed_on)
      xml.TimeSpan do
        xml.begin sorted.first.observed_on.to_s
        xml.end sorted.last.observed_on.to_s
      end
      
      xml << render(:partial => "observation", :collection => @observations)
    end
  end
end
