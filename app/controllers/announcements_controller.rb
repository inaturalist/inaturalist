class AnnouncementsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :admin_required
  before_filter :load_announcement, :only => [:show, :edit, :update, :destroy]
  before_filter :load_sites, only: [:new, :edit, :create]

  layout "bootstrap"
  
  # GET /announcements
  # GET /announcements.xml
  def index
    @announcements = Announcement.paginate(:page => params[:page])
  end
  
  def show
  end
  
  def new
    @announcement = Announcement.new
    respond_to do |format|
      format.html
    end
  end
  
  def edit
  end
  
  def create
    @announcement = Announcement.new(params[:announcement])

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
  
  private
  def load_announcement
    render_404 unless @announcement = Announcement.find_by_id(params[:id])
  end

  def load_sites
    @sites = Site.limit(100)
  end
  
end
