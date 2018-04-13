atom_feed({"xmlns"        => "http://www.w3.org/2005/Atom",
           "xmlns:georss" => "http://www.georss.org/georss"}) do |feed|
             
  feed.title("#{@site.name}: Observations by Everyone")
  feed.updated(@updated_at)
  feed.icon(image_path('favicon.png'))
  
  render(:partial => 'observation', :collection => @observations, :locals => {:feed => feed})
end
