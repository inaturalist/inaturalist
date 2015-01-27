class WikiPagesController < ApplicationController
  # acts_as_wiki_pages_controller
  accept_formats :html

  def edit_allowed?
    return false unless logged_in?
    return true if current_user.is_admin?
    if CONFIG.home_page_wiki_path && @page.path == CONFIG.home_page_wiki_path
      return false unless current_user.uri =~ /#{FakeView.root_url}/
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
