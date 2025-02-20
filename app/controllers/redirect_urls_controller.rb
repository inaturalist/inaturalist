# frozen_string_literal: true

class RedirectUrlsController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :admin_required, except: [:show]
  before_action :load_record, only: [:show, :edit, :update, :destroy]

  layout "bootstrap-container"

  # GET /redirect_urls
  def index
    @redirect_urls = RedirectUrl.page( params[:page] ).per_page( 100 )
  end

  # GET /redirect_urls/1
  def show
    @redirect_url.increment!( :view_count ) unless params[:test]
    mobile_os = request.headers["X_MOBILE_DEVICE"]
    redirect_target = if %w(android Android).include?( mobile_os ) || params[:force] == "android"
      @redirect_url.play_store_url
    elsif %w(iPhone iPad).include?( mobile_os ) || params[:force] == "ios"
      @redirect_url.app_store_url
    end
    if redirect_target
      redirect_to redirect_target
      return
    end
  end

  # GET /redirect_urls/new
  def new
    @redirect_url = RedirectUrl.new
  end

  # GET /redirect_urls/1/edit
  def edit
    @qr_code = RQRCode::QRCode.new( redirect_url_url( @redirect_url ) )
  end

  # POST /redirect_urls
  def create
    @redirect_url = RedirectUrl.new( redirect_url_params )
    @redirect_url.user = current_user

    if @redirect_url.save
      redirect_to redirect_urls_path, notice: "Redirect url was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /redirect_urls/1
  def update
    if @redirect_url.update( redirect_url_params )
      redirect_to redirect_urls_path, notice: "Redirect url was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /redirect_urls/1
  def destroy
    @redirect_url.destroy
    redirect_to redirect_urls_url, notice: "Redirect url was successfully destroyed."
  end

  private

  # Only allow a list of trusted parameters through.
  def redirect_url_params
    params.require( :redirect_url ).permit( :title, :description, :app_store_url, :play_store_url )
  end
end
