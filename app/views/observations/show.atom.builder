atom_feed({"xmlns"        => "http://www.w3.org/2005/Atom",
           "xmlns:georss" => "http://www.georss.org/georss"}) do |feed|
  feed.title("#{@observation.species_guess} observed by #{@observation.user.login}")
  feed.updated(@observation.updated_at)
  render(:partial => 'observation', :locals => {:feed => feed, :observation => @observation})
end
