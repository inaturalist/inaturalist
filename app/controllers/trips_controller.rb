class TripsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  before_filter :load_record, :only => [:show, :edit, :update, :destroy]
  before_filter :require_owner, :only => [:edit, :update, :destroy]
  before_filter :load_form_data, :only => [:new, :edit]

  layout "bootstrap"
  
  def index
    @trips = Trip.page(1)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: {:trips => @trips.as_json} }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @trip.as_json(:root => true) }
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

  def create
    @trip = Trip.new(params[:trip])
    @trip.user = current_user

    respond_to do |format|
      if @trip.save
        format.html { redirect_to @trip, notice: 'Trip was successfully created.' }
        format.json { render json: @trip.as_json(:root => true), status: :created, location: @trip }
      else
        format.html { render action: "new" }
        format.json { render json: @trip.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @trip.update_attributes(params[:trip])
        format.html { redirect_to @trip, notice: 'Trip was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @trip.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @trip.destroy

    respond_to do |format|
      format.html { redirect_to trips_url }
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
end
