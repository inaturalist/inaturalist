class TripsController < ApplicationController
  before_action :doorkeeper_authorize!, :only => [ :create, :update, :destroy, :by_login ], :if => lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, :except => [:index, :show, :by_login], :unless => lambda { authenticated_with_oauth? }
  before_filter :load_record, :only => [:show, :edit, :update, :destroy, :add_taxa_from_observations, :remove_taxa]
  before_filter :require_owner, :only => [:edit, :update, :destroy, :add_taxa_from_observations, :remove_taxa]
  before_filter :load_form_data, :only => [:new, :edit]
  before_filter :set_feature_test, :only => [:index, :show, :edit]
  before_filter :load_user_by_login, :only => [:by_login]

  layout "bootstrap"

  resource_description do
    description <<-EOT
      Trips are, well, trips. You go out to a place for a set period of time,
      you look for some stuff, hopefully you find some stuff, and then you
      write it up. Here, a Trip is a sublcass of Post, b/c these are
      essentially like blog posts with some added fields. Note that PUT, POST,
      and DELETE requests require an authenticated user who has permission to
      perform these actions (usually the user who created the resource).
    EOT
    formats %w(json)
  end
  
  api :GET, '/trips', 'Retrieve recently created trips'
  description <<-EOT
    If you're looking for
    pagination info, check the X headers in the response. You should see 
    <code>X-Total-Entries</code>, <code>X-Page</code>, and 
    <code>X-Per-Page</code>
  EOT
  param :page, :number, :desc => "Page of results"
  param :per_page, PER_PAGES, :desc => "Results per page"
  def index
    per_page = params[:per_page] unless PER_PAGES.include?(params[:per_page].to_i)
    per_page ||= 30
    @trips = Trip.published.page(params[:page]).per_page(per_page).order("posts.id DESC")

    respond_to do |format|
      format.html # index.html.erb
      format.json do
        pagination_headers_for(@trips)
        render json: {:trips => @trips.as_json}
      end
    end
  end

  api :GET, '/trips/:login', 'Retrieve recently created trips by a particular user'
  description <<-EOT
    If you're looking for
    pagination info, check the X headers in the response. You should see 
    <code>X-Total-Entries</code>, <code>X-Page</code>, and 
    <code>X-Per-Page</code>
  EOT
  param :login, String, :desc => "User login (username)"
  param :page, :number, :desc => "Page of results"
  param :per_page, PER_PAGES, :desc => "Results per page"
  param :published, [true,false,'any'], :desc => "Whether or not to return draft posts.", :default => true
  def by_login
    per_page = params[:per_page] unless PER_PAGES.include?(params[:per_page].to_i)
    per_page ||= 30
    @trips = Trip.where(:user_id => @selected_user).page(params[:page]).per_page(per_page).order("posts.id DESC")
    if current_user == @selected_user && params[:published].noish?
      @trips = @trips.unpublished
    elsif current_user == @selected_user && params[:published] == 'any'
      # return both
    else
      @trips = @trips.published
    end
    pagination_headers_for(@trips)
    respond_to do |format|
      format.json { render json: {:trips => @trips.as_json} }
    end
  end

  api :GET, '/trips/:id', "Get info about an existing trip"
  param :id, :number, :required => true
  def show
    respond_to do |format|
      format.html do
        @next = @trip.parent.journal_posts.published.where("published_at > ?", @trip.published_at || @trip.updated_at).order("published_at ASC").first
        @prev = @trip.parent.journal_posts.published.where("published_at < ?", @trip.published_at || @trip.updated_at).order("published_at DESC").first
        @shareable_image_url = @trip.body[/img.+?src="(.+?)"/, 1] if @trip.body
        @shareable_image_url ||= if @trip.parent_type == "Project"
          FakeView.image_url(@trip.parent.icon.url(:original))
        else
          FakeView.image_url(@trip.user.icon.url(:original))
        end
        @shareable_description = FakeView.shareable_description( @trip.body ) if @trip.body
        @trip_taxa = Taxon.sort_by_ancestry(@trip.trip_taxa.includes(:taxon)) do |a,b|
          a.taxon.name <=> b.taxon.name
        end
        trip_purpose_taxon_ids = @trip.trip_purposes.map(&:resource_id).flatten.uniq
        @trip_taxa_observed = []
        @trip_taxa_unobserved = []
        @trip_taxa_untargeted = []
        @trip_taxa.each do |tt|
          if tt.observed?
            @trip_taxa_observed << tt
            unless (trip_purpose_taxon_ids & tt.taxon.ancestor_ids).size > 0
              @trip_taxa_untargeted << tt
            end
          else
            @trip_taxa_unobserved << tt
          end
        end
      end
      format.json do
        @trip = Trip.includes(:trip_taxa => {:taxon => [:taxon_names, {:taxon_photos => :photo}]}, :trip_purposes => {}).where(:id => @trip.id).first
        render json: @trip.as_json(:root => true, :include => {
          :trip_taxa => {
            :include => {
              :taxon => {
                :only => [:id, :name, :ancestry], 
                :methods => [:default_name, :photo_url, :iconic_taxon_name, :conservation_status_name]
              }
            }
          },
          :trip_purposes => {
            :include => {
              :resource => {
                :except => [:delta, :auto_description, :source_url,
                  :source_identifier, :creator_id, :updater_id, :version,
                  :featured_at, :auto_photos, :locked, :wikipedia_summary,
                  :wikipedia_title, :name_provider, :source_id,
                  :conservation_status, :conservation_status_source_id,
                  :conservation_status_source_identifier]
              }
          }
          }
        })
      end
    end
  end

  def new
    @trip = Trip.new(:user => current_user)
    respond_to do |format|
      format.html
      format.json { render json: @trip.as_json(:root => true) }
    end
  end

  def edit
    @trip_taxa = @trip.trip_taxa
  end

  api :POST, '/trips', "Create a new trip"
  param :trip, Hash, :required => true, :desc => "Trip info" do
    param :title, String, :required => true
    param :body, String, :desc => "Description of the trip."
    param :latitude, :number, :desc => "Latitude of a point approximating the trip location."
    param :longitude, :number, :desc => "Longitude of a point approximating the trip location."
    param :radius, :number, :desc => "Radius in meters within which the trip occurred."
    param :place_id, :number, :desc => "Site place ID of place where the trip occurred."
    param :trip_taxa_attributes, Hash, :desc => "
      Nested trip taxa, i.e. taxa on the trip's check list. Note that this
      hash should be indexed uniquely for each trip taxon, e.g. <code>trip[trip_taxa_attributes][0][taxon_id]=xxx</code>
    " do
      param :taxon_id, :number, :desc => "Taxon ID"
      param :observed, [true, false], :desc => "Whether or not the taxon was observed"
    end
    param :trip_purposes_attributes, Hash, :desc => "
      Nested trip purposes, i.e. things sought on the trip (at this time only taxa are supported. Note that this
      hash should be indexed uniquely for each trip purpose, e.g. <code>trip[trip_purposes_attributes][0][taxon_id]=xxx</code>
    " do
      param :resource_type, ['Taxon'], :desc => "Purpose type. Only Taxon for now"
      param :resource_id, :number, :desc => "Taxon ID"
      param :complete, [true,false], :desc => "Whether or not this purposes should be considered accomplished, e.g. the user saught Homo sapiens and found one."
    end
  end
  def create
    @trip = Trip.new(params[:trip])
    @trip.user = current_user
    if params[:publish]
      @trip.published_at = Time.now
    elsif params[:unpublish]
      @trip.published_at = nil
    end

    respond_to do |format|
      if @trip.save
        format.html { redirect_to @trip, notice: 'Trip was successfully created.' }
        format.json { render json: @trip.as_json(:root => true), status: :created, location: @trip }
      else
        load_form_data
        format.html { render action: "new" }
        format.json { render json: @trip.errors, status: :unprocessable_entity }
      end
    end
  end

  api :PUT, '/trips/:id', "Update an existing trip"
  param :id, :number, :required => true
  param :trip, Hash, :required => true, :desc => "Trip info" do
    param :title, String, :required => true
    param :body, String, :desc => "Description of the trip."
    param :latitude, :number, :desc => "Latitude of a point approximating the trip location."
    param :longitude, :number, :desc => "Longitude of a point approximating the trip location."
    param :radius, :number, :desc => "Radius in meters within which the trip occurred."
    param :place_id, :number, :desc => "Site place ID of place where the trip occurred."
    param :trip_taxa_attributes, Hash, :desc => "
      Nested trip taxa, i.e. taxa on the trip's check list. Note that this
      hash should be indexed uniquely for each trip taxon, e.g.
      <code>trip[trip_taxa_attributes][0][taxon_id]=xxx</code>. When updating
      existing trip taxa, make sure you include their IDs, e.g.
      <code>trip[trip_taxa_attributes][0][id]=xxx</code>
    " do
      param :id, :number, :desc => "Trip taxon ID, required if you're updating an existing trip taxon"
      param :taxon_id, :number, :desc => "Taxon ID"
      param :observed, [true, false], :desc => "Whether or not the taxon was observed"
    end
    param :trip_purposes_attributes, Hash, :desc => "
      Nested trip purposes, i.e. things sought on the trip (at this time only
      taxa are supported. Note that this hash should be indexed uniquely for
      each trip taxon, e.g.
      <code>trip[trip_purposes_attributes][0][resource_id]=xxx</code>. When updating
      existing trip purposes, make sure you include their IDs, e.g.
      <code>trip[trip_purposes_attributes][0][id]=xxx</code>
    " do
      param :id, :number, :desc => "Trip purpose ID, required if you're updating an existing trip taxon"
      param :resource_type, ['Taxon'], :desc => "Purpose type. Only Taxon for now"
      param :resource_id, :number, :desc => "Taxon ID"
      param :complete, [true,false], :desc => "Whether or not this purposes should be considered accomplished, e.g. the user saught Homo sapiens and found one."
    end
  end
  def update
    if params[:publish]
      @trip.published_at = Time.now
    elsif params[:unpublish]
      @trip.published_at = nil
    end
    respond_to do |format|
      if @trip.update_attributes(params[:trip])
        format.html { redirect_to @trip, notice: 'Trip was successfully updated.' }
        format.json { head :no_content }
      else
        format.html do
          load_form_data
          render action: "edit"
        end
        format.json { render json: @trip.errors, status: :unprocessable_entity }
      end
    end
  end

  api :DELETE, "/trips/:id", "Delete an existing trip"
  param :id, :number, :required => true
  def destroy
    @trip.destroy

    respond_to do |format|
      format.html { redirect_to trips_url }
      format.json { head :no_content }
    end
  end

  def add_taxa_from_observations
    @trip_taxa = @trip.add_taxa_from_observations
    @saved, @unsaved = [], []
    @trip_taxa.each do |tt|
      if tt.persisted?
        @saved << tt
      else
        @unsaved << tt
      end
    end
    if @saved.size == 0 && @unsaved.size == 0
      msg = "Nothing new to add!"
    else
      msg = "Saved #{@saved.size} taxa"
      unless @unsaved.blank?
        msg += ", failed to add #{@unsaved.size}: #{@unsaved.map{|tt| "#{tt.taxon.try(:name)}: "+tt.errors.full_messages.to_sentence}.join(', ')}"
      end
    end
    respond_to do |format|
      format.html do
        flash[:notice] = msg
        redirect_back_or_default(edit_trip_path(@trip))
      end
      format.json do
        @saved.each_with_index do |tt,i|
          if @saved[i].taxon
            @saved[i].taxon.html = view_context.render_in_format(:html, :partial => "shared/taxon", :object => @saved[i].taxon)
          end
        end
        render :json => {
          :msg => msg,
          :saved => @saved.as_json(:include => {:taxon => {:methods => [:iconic_taxon_name, :html]}}),
          :unsaved => @saved.as_json(:include => [:taxon], :methods => [:errors])
        }
      end
    end
  end

  def remove_taxa
    @trip.trip_taxa.destroy_all
    respond_to do |format|
      format.html do
        flash[:notoce] = "Removed trip taxa"
      end
      format.json { head :no_content }
    end
  end

  private

  def load_form_data
    selected_names = %w(Aves Amphibia Reptilia Mammalia)
    @target_taxa = Taxon::ICONIC_TAXA.select{|t| selected_names.include?(t.name)}
    extra = Taxon.where("name in (?)", %w(Papilionoidea Hesperiidae Araneae Basidiomycota Magnoliophyta Pteridophyta))
    @target_taxa += extra
    @target_taxa = Taxon.sort_by_ancestry(@target_taxa)
    @target_taxa.each_with_index do |t,i|
      @target_taxa[i].html = render_to_string(:partial => "shared/taxon", :locals => {:taxon => t})
    end
  end

  def set_feature_test
    @feature_test = "trips"
  end
end
