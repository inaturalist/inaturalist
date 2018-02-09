class WikiPagesController < ApplicationController
  acts_as_wiki_pages_controller
  accept_formats :html

  def edit_allowed?
    return false unless logged_in?
    return true if current_user.is_admin?
    if !@site.home_page_wiki_path.blank? && @page.path == @site.home_page_wiki_path
      return false unless current_user.site_id == @site.id
    end
    current_user.is_curator?
  end

  def history_allowed?
    logged_in?
  end

  def setup_page
    if params[:path].blank?
      redirect_to root_url
    else
      super
    end
  end
end
