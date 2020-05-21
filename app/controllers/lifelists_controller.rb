class LifelistsController < ApplicationController

  before_filter :load_user, only: [:by_login]
  before_filter :admin_required

  def by_login
    respond_to do |format|
      format.html do
        render layout: "bootstrap"
      end
      format.csv do
        tmp_path = DynamicLifelist.export( @user )
        if tmp_path.blank?
          render json: { error: t(:internal_server_error) }, status: 500
          return
        end
        response.headers['Content-Disposition'] = "attachment; filename=\"#{File.basename(tmp_path)}\""
        render file: tmp_path
      end
    end
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