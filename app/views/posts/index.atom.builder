atom_feed({"xmlns"        => "http://www.w3.org/2005/Atom"}) do |feed|
  feed.title("#{CONFIG.site_name}: Journal by #{@parent_display_name}")
  feed.updated(@posts.first.created_at) unless @posts.empty?
  feed.icon("#{CONFIG.site_url}/images/favicon.png")
  
  render(:partial => 'post', :collection => @posts, 
    :locals => {:feed => feed})
end
