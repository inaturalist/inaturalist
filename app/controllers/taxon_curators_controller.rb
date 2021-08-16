class TaxonCuratorsController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required
  before_action :set_taxon_curator, only: [:show, :edit, :update, :destroy]

  respond_to :html
  layout "bootstrap"

  # def index
  #   @taxon_curators = TaxonCurator.all
  #   respond_with(@taxon_curators)
  # end

  # def show
  #   respond_with(@taxon_curator)
  # end

  def new
    @taxon_frameworks = TaxonFramework.select("taxon_frameworks.id, t.name").
        joins( "JOIN taxa t ON t.id = taxon_frameworks.taxon_id" ).
        where( "taxon_frameworks.rank_level IS NOT NULL" ).order( "t.name" ).limit( 1000 )
    @taxon_curator = TaxonCurator.new
    respond_with( @taxon_curator )
  end

  def edit
    @taxon_frameworks = TaxonFramework.includes( :taxon ).where( "taxon_frameworks.rank_level IS NOT NULL" ).order( "taxa.name" ).limit( 100 )
  end

  def create
    @taxon_curator = TaxonCurator.new( taxon_curator_params )
    @taxon_curator.save
    # respond_with(@taxon_curator)
    respond_to do |format|
      format.html { redirect_to taxonomy_details_for_taxon_path( @taxon_curator.taxon_framework.taxon) }
      format.json { render json: @taxon_curator }
    end
  end

  def update
    @taxon_curator.update( taxon_curator_params )
    respond_to do |format|
      format.html { redirect_to taxonomy_details_for_taxon_path( @taxon_curator.taxon_framework.taxon ) }
      format.json { render json: @taxon_curator }
    end
  end

  def destroy
    @taxon_curator.destroy
    respond_to do |format|
      format.html { redirect_to taxonomy_details_for_taxon_path( @taxon_curator.taxon_framework.taxon ) }
      format.json { render json: @taxon_curator }
    end
  end

  private
    def set_taxon_curator
      @taxon_curator = TaxonCurator.find( params[:id] )
    end

    def taxon_curator_params
      params.require( :taxon_curator ).permit( :taxon_framework_id, :user_id )
    end
end
