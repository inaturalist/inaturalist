class LifelistsController < ApplicationController

  before_filter :load_user, only: [:by_login]
  before_filter :admin_required

  def by_login
    if params[:place_id]
      @place = Place.find_by_id(params[:place_id])
    end
    render layout: "bootstrap"
  end

  def load_user
    params[:id] ||= params[:login]
    begin
      @user = User.find(params[:id])
    rescue
      @user = User.where("lower(login) = ?", params[:id].to_s.downcase).first
      @user ||= User.where( uuid: params[:id] ).first
      render_404 if @user.blank?
    end
  end

end
