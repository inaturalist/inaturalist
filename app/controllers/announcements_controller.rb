class AnnouncementsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :site_admin_required, except: [:dismiss]
  before_filter :load_announcement, :only => [:show, :edit, :update, :destroy, :dismiss]
  before_filter :load_sites, only: [:new, :edit, :create]

  layout "bootstrap"
  
  # GET /announcements
  # GET /announcements.xml
  def index
    @announcements = Announcement.order( "id desc" ).page( params[:page] )
    current_user_site_ids = current_user.site_admins.pluck(:site_id)
    unless current_user_site_ids.blank?
      @announcements = @announcements.joins(:sites).where( "sites.id": current_user_site_ids )
    end
    unless params[:q].blank?
      @announcements = @announcements.where( "body ilike ?", "%#{params[:q]}%" )
    end
  end
  
  def show
  end
  
  def new
    @announcement = Announcement.new
    if @site && !current_user.is_admin? && @site_admin = @site.site_admins.detect{|sa| sa.user_id == current_user.id }
      @announcement.sites = [@site]
    end
    respond_to do |format|
      format.html
    end
  end
  
  def edit
  end
  
  def create
    @announcement = Announcement.new(params[:announcement])
    if @site && !current_user.is_admin? && @site_admin = @site.site_admins.detect{|sa| sa.user_id == current_user.id }
      @announcement.sites = [@site]
    end
    respond_to do |format|
      if @announcement.save
        format.html { redirect_to(@announcement, :notice => t(:announcement_was_successfully_created)) }
      else
        format.html { render :action => "new" }
      end
    end
  end
  
  def update
    respond_to do |format|
      if @announcement.update_attributes(params[:announcement])
        format.html { redirect_to(@announcement, :notice => t(:announcement_was_successfully_updated)) }
      else
        format.html { render :action => "edit" }
      end
    end
  end
  
  def destroy
    @announcement.destroy

    respond_to do |format|
      format.html { redirect_to(announcements_url) }
      format.xml  { head :ok }
    end
  end

  def dismiss
    unless @announcement.dismiss_user_ids.include?( current_user.id )
      @announcement.dismiss_user_ids << current_user.id
    end
    @announcement.save!
    respond_to do |format|
      format.any { head :ok }
      format.html { redirect_back_or_default( dashboard_path ) }
    end
  end
  
  private
  def load_announcement
    render_404 unless @announcement = Announcement.find_by_id(params[:id])
  end

  def load_sites
    @sites = Site.limit(100)
  end
  
end
