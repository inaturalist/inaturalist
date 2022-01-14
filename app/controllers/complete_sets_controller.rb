class CompleteSetsController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required
  before_action :find_complete_set, except: [:new, :create]
  layout "bootstrap"

  def new
    @complete_set = CompleteSet.new( taxon_id: params[:taxon_id].to_i, place_id: params[:place_id].to_i )
  end
  
  def edit
  end

  def show
    @taxa = @complete_set.get_taxa_for_place_taxon
    @listed_taxon_alterations = @complete_set.relevant_listed_taxon_alterations.
      order( "listed_taxon_alterations.created_at DESC" ).limit( 30 ).reverse    
    
    #any obs outside of the complete set
    @observation_search_url_params = { 
      rank: ["species","subspecies","variety","form"], verifiable: true, taxon_id: @complete_set.taxon_id, 
      place_id: @complete_set.place_id, without_taxon_id: @taxa.pluck(:id).join( "," )
    }
    @num_obs = INatAPIService.observations( @observation_search_url_params.merge( per_page: 0 ) ).total_results
  end

  def create
    @complete_set = CompleteSet.new( params[:complete_set] )
    respond_to do |format|
      if @complete_set.save
        format.html { redirect_to( @complete_set, notice: "Complete Set was successfully created." ) }
      else
        format.html { render action: "new" }
      end
    end
  end

  def update
    respond_to do |format|
      if @complete_set.update( params[:complete_set] )
        format.html { redirect_to( @complete_set, notice: "Complete Set was successfully updated." ) }
      else
        format.html { render action: "edit" }
      end
    end
  end

  def destroy
    @complete_set.destroy
    respond_to do |format|
      format.html { redirect_to( @complete_set.place ) }
    end
  end

  def destroy_relevant_listings
    taxon_id = params[:taxon_id]
    place = @complete_set.place
    lts = ListedTaxon.get_defaults_for_taxon_place( place.id, taxon_id )
    if lts.count > 0
      lts.map{|lt| lt.updater = current_user}
      lts.destroy_all
    end
    respond_to do |format|
      format.json { render json: {}, status: :ok }
    end
  end

  def get_relevant_listings
    taxon_id = params[:taxon_id]
    place = @complete_set.place
    lt = ListedTaxon.get_defaults_for_taxon_place( place.id, taxon_id, { limit: 10 } )
    render json: lt, include: { taxon: { only: :name }, place: { only: :name } }, only: :id
  end

  def remove_listed_taxon_alteration
    lta_id = params[:lta_id]
    lta = ListedTaxonAlteration.find( lta_id )
    lta.destroy
    respond_to do |format|
      format.json { render json: {}, status: :ok }
    end
  end

  private

  def find_complete_set
    begin
      @complete_set = CompleteSet.find( params[:id] )
    rescue
      render_404
    end
  end
end
