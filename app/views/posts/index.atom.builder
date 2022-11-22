atom_feed({"xmlns"        => "http://www.w3.org/2005/Atom"}) do |feed|
  feed.title("#{@site.name}: Journal by #{@parent.journal_display_name}")
  feed.updated(@posts.first.created_at) unless @posts.empty?
  feed.icon(image_path('favicon.png'))
  
  render(:partial => 'post', :collection => @posts, 
    :locals => {:feed => feed})
end
