# frozen_string_literal: true

class WikiPagesController < ApplicationController
  acts_as_wiki_pages_controller
  accept_formats :html

  protected

  def edit_allowed?
    return false unless logged_in?
    return true if current_user.is_admin?

    if current_user.is_site_admin_of?( @site )
      return true if @page.creator.blank?
      return true if !@page.creator.is_admin? && @page.creator.is_site_admin_of?( @site )
    end
    if !@site.home_page_wiki_path.blank? && @page.path == @site.home_page_wiki_path && current_user.site_id != @site.id
      return false
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

  def permitted_page_params
    params.require( :page ).permit(
      :admin_only,
      :comment,
      :content,
      :previous_version_number,
      :title
    )
  end

  def not_allowed
    msg = t( :you_dont_have_permission_to_do_that )
    respond_to do | format |
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
