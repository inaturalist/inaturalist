atom_feed({"xmlns"        => "http://www.w3.org/2005/Atom",
           "xmlns:georss" => "http://www.georss.org/georss"}) do |feed|
             
  feed.title(raw t(:inaturalist_observations_by, :login => @login, :site_name => SITE_NAME ) )
  feed.updated(@observations.first.created_at) unless @observations.empty?
  feed.icon("#{CONFIG.site_url}/images/favicon.png")
  
  render(:partial => 'observation', :collection => @observations, 
    :locals => {:feed => feed})
end
