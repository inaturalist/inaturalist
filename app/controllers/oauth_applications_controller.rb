# frozen_string_literal: true

class OauthApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_application, only: [:show, :edit, :update, :destroy]
  before_action :require_owner_or_admin, only: [:edit, :update, :destroy]
  before_action :require_app_owner_or_admin, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_eligible, only: [:app_owner_application, :create_app_owner_application]
  respond_to :html

  layout "bootstrap"

  MIN_EXPLANATION_LENGTH = 20

  def index
    @applications = OauthApplication.paginate( page: params[:page] )
  end

  def new
    @application = OauthApplication.new
  end

  def create
    @application = OauthApplication.new( allowed_params )
    @application.owner = current_user
    if @application.save
      flash[:notice] = I18n.t( :notice, scope: [:doorkeeper, :flash, :applications, :create] )
      redirect_to oauth_application_path( @application )
    else
      render :new
    end
  end

  def show; end

  def edit; end

  def update
    if @application.update( allowed_params )
      flash[:notice] = I18n.t( :notice, scope: [:doorkeeper, :flash, :applications, :update] )
      redirect_to oauth_application_path( @application )
    else
      render :edit
    end
  end

  def destroy
    flash[:notice] = I18n.t( :notice, scope: [:doorkeeper, :flash, :applications, :destroy] ) if @application.destroy
    redirect_to oauth_applications_url
  end

  def app_owner_application
    if current_user.is_app_owner?
      flash[:notice] = I18n.t( :user_already_app_owner )
      redirect_to oauth_applications_url
    end
    @app_owner_application = {}
  end

  def create_app_owner_application
    if params[:application].to_s.size < MIN_EXPLANATION_LENGTH
      flash[:error] = t( :app_owner_application_explanation_required )
      @app_owner_application = params[:application] || {}
      render :app_owner_application
    elsif !@eligible
      flash[:error] = t( :app_owner_application_inelligible )
      @app_owner_application = params[:application] || {}
      render :app_owner_application
    elsif current_user.is_app_owner?
      flash[:notice] = I18n.t( :user_already_app_owner )
      redirect_to oauth_applications_url
    else
      Emailer.app_owner_application( current_user, params[:application] ).deliver_now
      flash[:notice] = t( :app_owner_application_success )
      redirect_to oauth_applications_url
    end
  end

  private

  def set_eligible
    last_months_improving_ids_count = Identification.elastic_search(
      filters:
        [
          { term: { current: true } },
          { term: { "user.id" => current_user.id } },
          { term: { category: "improving" } },
          { term: { own_observation: false } },
          { range: { created_at: { gte: 1.month.ago } } },
          { range: { created_at: { lte: 0.months.ago } } }
        ]
    ).total_entries
    @eligible = current_user.is_admin? ||
      ( last_months_improving_ids_count >= 10 && current_user.created_at < 2.months.ago )
  end

  def load_application
    render_404 unless ( @application = OauthApplication.find_by_id( params[:id] ) )
    @application = @application.becomes( OauthApplication )
  end

  def require_owner_or_admin
    return if logged_in? && ( current_user.id == @application.owner_id || current_user.admin? )

    flash[:error] = I18n.t( :you_dont_have_permission_to_do_that )
    redirect_to root_url
  end

  def require_app_owner_or_admin
    return if logged_in? && ( current_user.is_app_owner? || current_user.admin? )

    flash[:error] = I18n.t( :you_dont_have_permission_to_do_that )
    redirect_to oauth_applications_url
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
    params.require( :oauth_application ).permit( *permitted )
  end
end
