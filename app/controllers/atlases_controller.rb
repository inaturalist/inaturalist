class AtlasesController < ApplicationController
  before_action :authenticate_user!
  before_action :curator_required, :only => [:new, :create, :edit, :update,
    :destroy, :alter_atlas_presence, :destroy_all_alterations, :remove_atlas_alteration,
    :remove_listed_taxon_alteration, :refresh_atlas]
  before_action :find_atlas, except: [ :new, :create, :index ]
  layout "bootstrap"

  def new
    @atlas = Atlas.new( taxon_id: params[:taxon_id].to_i )
  end

  def edit
    load_for_edit
  end

  def show
    @atlas_places = @atlas.places
    @atlas_presence_places_with_establishment_means = @atlas.presence_places_with_establishment_means
    @atlas_presence_places_with_establishment_means_hash = Hash[@atlas_presence_places_with_establishment_means.map{ |e| [ e[:id], e[:establishment_means] ] }]
    @exploded_places = Hash[@atlas.exploded_atlas_places.map{ |e| [ e.place_id, e.id ] }]
    @atlas_presence_places_with_establishment_means_hash_json = @atlas_presence_places_with_establishment_means_hash.to_json
    @exploded_places_json = @exploded_places.to_json
    
    #any obs outside of the atlas
    @observations_not_in_atlas_places_params = Atlas::NOT_IN_ATLAS_PARAMS.merge( { 
      taxon_id: @atlas.taxon_id, 
      not_in_place: @atlas_presence_places_with_establishment_means.map{|p| p[:id] }.join( "," )
    } )
    @num_obs_not_in_atlas_places = INatAPIService.observations( @observations_not_in_atlas_places_params.merge( per_page: 0 ) ).total_results
    respond_to do |format|
      format.html do
        @is_curator = "#{current_user.is_curator?}"
        @atlas_alterations = @atlas.atlas_alterations.includes( :place, :user ).order( "created_at DESC" ).
          limit( 30 ).reverse
        @listed_taxon_alterations = @atlas.relevant_listed_taxon_alterations.includes( :place, :user ).
          order( "listed_taxon_alterations.created_at DESC" ).limit( 30 ).reverse
      end
      format.json { render json: {
          presence_places: @atlas_presence_places_with_establishment_means_hash,
          exploded_places: @exploded_places
        }
      }
    end
  end
  
  def index
    filter_params = params[:filters] || params
    @taxon = Taxon.find_by_id( filter_params[:taxon_id].to_i ) unless filter_params[:taxon_id].blank?
    @is_active = filter_params[:is_active]
    @is_marked = filter_params[:is_marked]
    
    scope = Atlas.all
    scope = scope.taxon(@taxon) if @taxon
    if @is_active.yesish?
      scope = scope.active
    elsif @is_active.noish?
      scope = scope.inactive
    end
    if @is_marked.yesish?
      scope = scope.marked
    elsif @is_marked.noish?
      scope = scope.unmarked
    end
    
    @atlases = scope.page(params[:page]).per_page(10)
  end

  def create
    @atlas = Atlas.new( params[:atlas].merge(:user_id => current_user.id) )
    respond_to do |format|
      if @atlas.save
        format.html { redirect_to( @atlas, notice: "Atlas was successfully created." ) }
      else
        format.html { render action: "new" }
      end
    end
  end

  def update
    respond_to do |format|
      if @atlas.update( params[:atlas] )
        @atlas.taxon
        format.html { redirect_to( @atlas, notice: "Atlas was successfully updated." ) }
      else
        load_for_edit
        format.html { render action: "edit" }
      end
    end
  end

  def destroy
    @atlas.destroy
    respond_to do |format|
      format.html { redirect_to( @atlas.taxon ) }
    end
  end

  ## Custom actions ############################################################

  def alter_atlas_presence
    taxon_id = params[:taxon_id]
    place_id = params[:place_id]
    place = Place.find( place_id )
    taxon = Taxon.find( taxon_id )
    lts = taxon.atlas.get_atlas_presence_place_listed_taxa( place_id )
    error = nil
    presence = "not allowed"
    if lts.count > 0
      lts.each do |lt|
        lt.updater = current_user
        lt.destroy
      end
      presence = false
    elsif ( list = place.check_list )

      # If there are other potentially relevant comprehensive lists, those
      # need to be added to as well otherwise the validation for our new
      # listed taxon will fail
      comprehensive_ancestor_check_lists = CheckList.where(
        "comprehensive AND lists.taxon_id IN (?) AND lists.place_id IN (?)",
        taxon.ancestor_ids, place.self_and_ancestor_ids
      )
      if comprehensive_ancestor_check_lists.exists?
        ancestor_place_ids = place.ancestor_ids
        # Order these by higher ranked taxa and higher ranked places
        comprehensive_ancestor_check_lists = comprehensive_ancestor_check_lists.
          includes(:taxon).
          limit( 500 ).
          sort_by{ |cl| [cl.taxon.rank_level.to_i * -1, ancestor_place_ids.index(cl.place_id).to_i ]}
        comprehensive_ancestor_check_lists.each do |check_list|
          check_list.add_taxon( taxon, user: current_user )
        end
      end

      lt = list.listed_taxa.find_by_taxon_id( taxon_id )
      lt ||= ListedTaxon.create( taxon_id: taxon_id, place_id: place_id, list_id: list.id, user_id: current_user.id )

      if lt.errors.any?
        presence = "not allowed"
        error = lt.errors.full_messages.to_sentence
      else
        presence = true
      end
    else
      error = "#{place.display_name} has no check list"
    end


    unless presence
      comprehensive_list = place.check_lists.where( "comprehensive AND lists.taxon_id IN (?)", taxon.self_and_ancestor_ids ).first
      if comprehensive_list && comprehensive_lt = comprehensive_list.listed_taxa.where( taxon: taxon ).first
        comprehensive_lt.updater = current_user
        comprehensive_lt.destroy
      end
    end

    respond_to do |format|
      format.json do
        if error
          render json: { place_name: place.try_methods( :display_name, :name ), place_id: place_id, presence: presence, error: error }, status: :unprocessable_entity
        else
          render json: { place_name: place.try_methods( :display_name, :name ), place_id: place_id, presence: presence }, status: :ok
        end
      end
    end
  end

  def destroy_all_alterations
    atlas_id = @atlas.id
    AtlasAlteration.where( atlas_id: atlas_id ).destroy_all
    respond_to do |format|
      format.json { render json: {}, status: :ok }
    end
  end

  def remove_atlas_alteration
    aa_id = params[:aa_id]
    aa = AtlasAlteration.find( aa_id )
    aa.destroy
    respond_to do |format|
      format.json { render json: {}, status: :ok}
    end
  end

  def remove_listed_taxon_alteration
    lta_id = params[:lta_id]
    lta = ListedTaxonAlteration.find( lta_id )
    lta.destroy
    respond_to do |format|
      format.json { render json: {}, status: :ok }
    end
  end

  def get_defaults_for_taxon_place
    taxon_id = params[:taxon_id]
    place_id = params[:place_id]
    lt = ListedTaxon.get_defaults_for_taxon_place( place_id, taxon_id, { limit: 10 } )
    render json: lt, include: { taxon: { only: :name }, place: { only: [:name, :display_name] } }, only: :id
  end
  
  def refresh_atlas
    is_marked = Atlas.still_is_marked(@atlas)
    respond_to do |format|
      format.json { render json: is_marked, status: :ok }
    end
  end

  private

  def find_atlas
    begin
      @atlas = Atlas.find( params[:id] )
    rescue
      render_404
    end
  end

  def load_for_edit
    @exploded_atlas_places = @atlas.exploded_atlas_places.includes( :place )
    @atlas_places = @atlas.places
  end

end
