class LifelistsController < ApplicationController

  before_action :load_user, only: [:by_login]

  def by_login
    if params[:place_id]
      @place = Place.find_by_id(params[:place_id])
    end
    @flash_js = true
    render layout: "bootstrap"
  end

  def load_user
    begin
      @user = User.find(params[:login])
    rescue
      @user = User.where("lower(login) = ?", params[:login].to_s.downcase).first
      @user ||= User.where( uuid: params[:login] ).first
      render_404 if @user.blank?
    end
  end


  private

  def admin_or_test_group_required
    unless logged_in? && ( current_user.is_admin? || current_user.in_test_group?( "lifelists" ) )
      only_admins_failure_state
    end
  end


end
