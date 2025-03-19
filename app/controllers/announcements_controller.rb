# frozen_string_literal: true

class AnnouncementsController < ApplicationController
  before_action :authenticate_user!, except: [:active]
  before_action :site_admin_required, except: [:active, :dismiss]
  before_action :load_announcement, only: [:show, :edit, :update, :destroy, :dismiss]
  before_action :load_sites, only: [:new, :edit, :create]

  layout "bootstrap"

  # GET /announcements
  # GET /announcements.xml
  def index
    @announcements = Announcement.includes( :sites ).order( "announcements.id desc" ).page( params[:page] )
    @announcements = @announcements.where( sites: { id: current_user_site_ids } ) unless current_user_site_ids.blank?
    @announcements = @announcements.where( "body ilike ?", "%#{params[:q]}%" ) unless params[:q].blank?
    @active = params[:active].yesish?
    @announcements = @announcements.where( "\"end\" > ?", Time.now ) if @active
    @placement = params[:placement] if Announcement::PLACEMENTS.include?( params[:placement] )
    @announcements = @announcements.where( placement: @placement ) unless @placement.blank?
  end

  def active
    @announcements = Announcement.active(
      placement: params[:placement],
      client: params[:client],
      user_agent_client: user_agent_client,
      user: current_user,
      site: @site
    )
    @announcements.each do | announcement |
      helpers.create_announcement_impression( announcement )
    end

    respond_to do | format |
      format.json { render json: @announcements }
    end
  end

  def show
    respond_to do | format |
      format.html do
        if params[:body]
          return render html: "<html><body style='margin: 0'>#{@announcement.body}</body></html>".html_safe
        end
      end
    end
  end

  def new
    @announcement = Announcement.new
    if @site &&
        !current_user.is_admin? &&
        ( @site_admin = @site.site_admins.detect {| sa | sa.user_id == current_user.id } )
      @announcement.sites = [@site]
    end
    respond_to( &:html )
  end

  def edit; end

  def create
    @announcement = Announcement.new( params[:announcement] )
    if @site &&
        !current_user.is_admin? &&
        ( @site_admin = @site.site_admins.detect {| sa | sa.user_id == current_user.id } )
      @announcement.sites = [@site]
    end
    respond_to do | format |
      if @announcement.save
        format.html { redirect_to( @announcement, notice: t( :announcement_was_successfully_created ) ) }
      else
        format.html { render action: "new" }
      end
    end
  end

  def update
    respond_to do | format |
      if @announcement.update( params[:announcement] )
        format.html { redirect_to( @announcement, notice: t( :announcement_was_successfully_updated ) ) }
      else
        format.html { render action: "edit" }
      end
    end
  end

  def destroy
    @announcement.destroy

    respond_to do | format |
      format.html { redirect_to( announcements_url ) }
      format.xml  { head :ok }
    end
  end

  def dismiss
    unless @announcement.dismiss_user_ids.include?( current_user.id )
      @announcement.dismiss_user_ids << current_user.id
    end
    @announcement.save!
    Logstasher.write_announcement_dismissal( @announcement, request: request, user: current_user )

    respond_to do | format |
      format.any { head :no_content }
      format.html { redirect_back_or_default( dashboard_path ) }
    end
  end

  private

  def current_user_site_ids
    @current_user_site_ids ||= current_user.site_admins.pluck( :site_id )
  end

  def load_announcement
    render_404 unless ( @announcement = Announcement.find_by_id( params[:id] ) )
  end

  def load_sites
    @sites = Site.limit( 100 )
  end

  def user_agent_client
    user_agent = request.headers["User-Agent"]
    return if user_agent.blank?

    return Announcement::INATRN if user_agent =~ /iNaturalistReactNative|iNaturalistRN/
    return Announcement::SEEK if user_agent =~ /Seek/
    return Announcement::INAT_IOS if user_agent =~ %r{iNaturalist/.*Darwin}
    return Announcement::INAT_ANDROID if user_agent =~ %r{iNaturalist/.*Android}

    nil
  end
end
