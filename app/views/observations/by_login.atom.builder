atom_feed({"xmlns"        => "http://www.w3.org/2005/Atom",
           "xmlns:georss" => "http://www.georss.org/georss"}) do |feed|
             
  feed.title("iNaturalist: Observations by #{@login}")
  feed.updated(@observations.first.created_at) unless @observations.empty?
  feed.icon("http://inaturalist.org/images/favicon.png")
  
  render(:partial => 'observation', :collection => @observations, 
    :locals => {:feed => feed})
end
