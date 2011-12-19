class INatLinkRenderer < WillPaginate::LinkRenderer
  def rel_value(page)
    "nofollow"
  end
end