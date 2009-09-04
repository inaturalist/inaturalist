atom_feed({"xmlns"        => "http://www.w3.org/2005/Atom"}) do |feed|
  feed.title("iNaturalist: Journal by #{@display_user.login}")
  feed.updated(@posts.first.created_at) unless @posts.empty?
  feed.icon("http://inaturalist.org/images/favicon.png")
  
  render(:partial => 'post', :collection => @posts, 
    :locals => {:feed => feed})
end
