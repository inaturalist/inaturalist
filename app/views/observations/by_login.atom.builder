atom_feed({"xmlns"        => "http://www.w3.org/2005/Atom",
           "xmlns:georss" => "http://www.georss.org/georss"}) do |feed|
  feed.title t(:observations_by_user, user: @login )
  feed.updated( @observations.first.created_at ) unless @observations.empty?
  feed.icon @site && @site.favicon? ? @site.favicon.url : image_path( "favicon.png" )
  render partial: "observation", collection: @observations, locals: { feed: feed }
end
