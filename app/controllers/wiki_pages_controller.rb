class WikiPagesController < ApplicationController
  acts_as_wiki_pages_controller
  accept_formats :html

  protected

  def edit_allowed?
    return false unless logged_in?
    return true if current_user.is_admin?
    if !@site.home_page_wiki_path.blank? && @page.path == @site.home_page_wiki_path
      return false unless current_user.site_id == @site.id
    end
    return false if @page.admin_only?
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

  def wiki_page_permitted_params
    [:previous_version_number, :title, :content, :comment, :admin_only]
  end

  def not_allowed
    msg = t(:you_dont_have_permission_to_do_that)
    respond_to do |format|
      format.html do
        flash[:error] = msg
        return redirect_back_or_default root_url
      end
      format.json do
        return render json: { error: msg }, status: :forbidden
      end
    end
  end
end
