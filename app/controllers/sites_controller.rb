class SitesController < ApplicationController
  before_filter :authenticate_user!
  before_filter :admin_required, :only => [:new, :create, :destroy]
  before_filter :load_record, :only => [:show, :edit, :update, :destroy]
  before_filter :site_admin_required, :only => [:edit, :update]
  before_filter :setup_pref_groups, :only => [:new, :create, :edit, :update]

  layout "bootstrap"

  # GET /sites
  # GET /sites.json
  def index
    @sites = Site.page(params[:page])

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @sites }
    end
  end

  # GET /sites/1
  # GET /sites/1.json
  def show
    @site = Site.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @site }
    end
  end

  # GET /sites/new
  # GET /sites/new.json
  def new
    @site = Site.new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @site }
    end
  end

  # GET /sites/1/edit
  def edit
    @site = Site.find(params[:id])
  end

  # POST /sites
  # POST /sites.json
  def create
    @site = Site.new(params[:site])

    respond_to do |format|
      if @site.save
        format.html { redirect_to @site, notice: 'Site was successfully created.' }
        format.json { render json: @site, status: :created, location: @site }
      else
        format.html { render action: "new" }
        format.json { render json: @site.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /sites/1
  # PUT /sites/1.json
  def update
    @site = Site.find(params[:id])

    respond_to do |format|
      if @site.update_attributes(params[:site])
        format.html { redirect_to @site, notice: 'Site was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @site.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sites/1
  # DELETE /sites/1.json
  def destroy
    @site = Site.find(params[:id])
    @site.destroy

    respond_to do |format|
      format.html { redirect_to sites_url }
      format.json { head :no_content }
    end
  end

  private

  def site_admin_required
    unless current_user.is_admin? || @site_admin = @site.site_admins.where(:user_id => current_user).first
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
end
