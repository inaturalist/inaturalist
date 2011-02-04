xml.instruct!
@prevent_cache = "?prevent=#{rand(1024)}"

xml.kml "xmlns" => "http://www.opengis.net/kml/2.2" do
  
  xml.NetworkLinkControl do
        
    xml.minRefreshPeriod("5")
    xml.linkName(@net_hash[:name])
    xml.linkDescription(@net_hash[:description])
    xml.linkSnippet(@net_hash[:snippet], :maxLines=>"2")
    
  end
  
  xml.Document do  
    render :partial => "observation", :collection => @observations
  end
end
