# frozen_string_literal: true

class RedirectLinksController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :admin_required, except: [:show]
  before_action :load_record, only: [:show, :edit, :update, :destroy]

  layout "bootstrap-container"

  # GET /redirect_links
  def index
    @redirect_links = RedirectLink.order( "id desc" ).page( params[:page] ).per_page( 100 )
  end

  # GET /redirect_links/1
  def show
    @redirect_link.increment!( :view_count ) unless params[:test]
    mobile_os = request.headers["X_MOBILE_DEVICE"]
    redirect_target = if %w(android Android).include?( mobile_os ) || params[:force] == "android"
      @redirect_link.play_store_url
    elsif %w(iPhone iPad).include?( mobile_os ) || params[:force] == "ios"
      @redirect_link.app_store_url
    end
    if mobile_os
      @responsive = true
      @footless = true
      @no_footer_gap = true
    end
    # If we don't know where to send the user, show them the default choice
    # page
    return unless redirect_target

    redirect_to redirect_target
  end

  # GET /redirect_links/new
  def new
    @redirect_link = RedirectLink.new
  end

  # GET /redirect_links/1/edit
  def edit
    @qr_code = RQRCode::QRCode.new( redirect_link_url( @redirect_link ) )
  end

  # POST /redirect_links
  def create
    @redirect_link = RedirectLink.new( redirect_link_params )
    @redirect_link.user = current_user

    if @redirect_link.save
      redirect_to redirect_links_path, notice: "Redirect link was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /redirect_links/1
  def update
    if @redirect_link.update( redirect_link_params )
      redirect_to redirect_links_path, notice: "Redirect link was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /redirect_links/1
  def destroy
    @redirect_link.destroy
    redirect_to redirect_links_url, notice: "Redirect link was successfully destroyed."
  end

  private

  # Only allow a list of trusted parameters through.
  def redirect_link_params
    params.require( :redirect_link ).permit( :title, :description, :app_store_url, :play_store_url )
  end
end
