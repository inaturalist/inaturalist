class SitesController < ApplicationController
  before_filter :authenticate_user!, except: %w(network affiliation)
  before_filter :load_site, only: [:show, :edit, :update, :destroy, :export]
  before_filter :admin_or_any_site_admin_required, only: [:index, :show]
  before_filter :require_admin_of_viewed_site, except: [:index, :show,
    :network, :affiliation]
  before_filter :setup_pref_groups, only: [:new, :create, :edit, :update, :show]

  layout "bootstrap"

  # GET /sites
  # GET /sites.json
  def index
    @records = Site.page(params[:page]).order(:id)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @records }
    end
  end

  # GET /sites/1
  # GET /sites/1.json
  def show
    @record = Site.find(params[:id])
    @record_admin ||= @record.site_admins.where( user_id: current_user ).first

    if current_user.is_admin? || @record_admin
      export_path = @record.export_path
      if File.exists?( export_path )
        @export_url = export_site_url( @record )
        @export_mtime = File.mtime( export_path )
        @export_bytes = File.size( export_path )
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @record }
    end
  end

  # GET /sites/new
  # GET /sites/new.json
  def new
    @record = Site.new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @record }
    end
  end

  # GET /sites/1/edit
  def edit
    @record = Site.find(params[:id])
  end

  # POST /sites
  # POST /sites.json
  def create
    @record = Site.new(params[:site])

    respond_to do |format|
      if @record.save
        format.html { redirect_to @record, notice: 'Site was successfully created.' }
        format.json { render json: @record, status: :created, location: @record }
      else
        format.html { render action: "new" }
        format.json { render json: @record.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /sites/1
  # PUT /sites/1.json
  def update
    @record = Site.find(params[:id])

    respond_to do |format|
      if @record.update_attributes(params[:site])
        if Site.default && @record.id == Site.default.id
          Site.default( refresh: true )
        end
        format.html { redirect_to @record, notice: 'Site was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @record.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sites/1
  # DELETE /sites/1.json
  def destroy
    @record = Site.find(params[:id])
    @record.destroy

    respond_to do |format|
      format.html { redirect_to sites_url }
      format.json { head :no_content }
    end
  end

  def network
    @page_title = t( "views.stats.year.inaturalist_network" )
    render layout: "bootstrap-container"
  end

  def affiliation
    @page_title = t(:inaturalist_network_affiliation)
    render layout: "bootstrap-container"
  end

  def export
    path = @record.export_path
    return render_404 unless File.exists?( path )
    send_file path
  end

  private

  def require_admin_of_viewed_site
    unless current_user.is_admin? || 
        ( @record && @record_admin = @record.site_admins.where( user_id: current_user ).first )
      redirect_to_hell 
    end
  end

  def setup_pref_groups
    pref_hash = {}
    Site.preference_definitions.each do |name,pref|
      key = name.split('_').first
      pref_hash[key] ||= []
      pref_hash[key] << pref
    end
    @pref_groups = {}
    pref_hash.each do |k,v|
      if v.size == 1
        @pref_groups["Other"] ||= []
        @pref_groups["Other"] += v
      else
        @pref_groups[k] = v
      end
    end
  end

  def load_site
    record = Site.find(params[:id] || params[:site_id]) rescue nil
    @record = record
    render_404 unless record
  end
end
