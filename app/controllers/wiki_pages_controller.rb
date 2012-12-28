class WikiPagesController < ApplicationController
  acts_as_wiki_pages_controller
  def edit_allowed?
    logged_in? && (current_user.is_curator? || current_user.is_admin?)
  end

  def history_allowed?
    edit_allowed?
  end

  def setup_page
    if params[:path].blank?
      redirect_to root_url
    else
      super
    end
  end
end
