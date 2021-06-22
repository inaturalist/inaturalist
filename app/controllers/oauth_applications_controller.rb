class OauthApplicationsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_application, :only => [:show, :edit, :update, :destroy]
  before_filter :require_owner_or_admin, :only => [:edit, :update, :destroy]
  respond_to :html

  def index
    @applications = OauthApplication.paginate(:page => params[:page])
  end

  def new
    @application = OauthApplication.new
  end

  def create
    @application = OauthApplication.new( allowed_params )
    @application.owner = current_user
    if @application.save
      flash[:notice] = I18n.t(:notice, :scope => [:doorkeeper, :flash, :applications, :create])
      redirect_to oauth_application_path(@application)
    else
      render :new
    end
  end

  def show
  end

  def edit
  end

  def update
    if @application.update_attributes( allowed_params )
      flash[:notice] = I18n.t(:notice, :scope => [:doorkeeper, :flash, :applications, :update])
      redirect_to oauth_application_path(@application)
    else
      render :edit
    end
  end

  def destroy
    flash[:notice] = I18n.t(:notice, :scope => [:doorkeeper, :flash, :applications, :destroy]) if @application.destroy
    redirect_to oauth_applications_url
  end

  private

  def load_application
    render_404 unless @application = OauthApplication.find_by_id(params[:id])
    @application = @application.becomes(OauthApplication)
  end

  def require_owner_or_admin
    unless logged_in? && (current_user.id == @application.owner_id || current_user.admin?)
      flash[:error] = "You don't have permission to do that"
      return redirect_to root_url
    end
  end

  def allowed_params
    permitted = [
      :image,
      :name,
      :redirect_uri,
      :confidential,
      :description,
      :url
    ]
    if current_user.is_admin?
      permitted += [:official, :trusted]
    end
    params.require(:oauth_application).permit( *permitted )
  end
end
