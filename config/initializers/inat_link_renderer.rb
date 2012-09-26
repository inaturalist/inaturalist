class INatLinkRenderer < WillPaginate::ActionView::LinkRenderer 
  def rel_value(page)
    "nofollow"
  end
end