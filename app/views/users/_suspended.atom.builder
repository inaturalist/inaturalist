atom_feed({"xmlns"        => "http://www.w3.org/2005/Atom",
           "xmlns:georss" => "http://www.georss.org/georss"}) do |feed|
             
  feed.title(t("views.users.show.this_user_was_banned"))
  feed.icon(image_path('favicon.png'))
end
