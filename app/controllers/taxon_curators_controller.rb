class TaxonCuratorsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :admin_required
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
    @taxon_curator = TaxonCurator.new
    respond_with(@taxon_curator)
  end

  def edit
  end

  def create
    @taxon_curator = TaxonCurator.new(taxon_curator_params)
    @taxon_curator.save
    # respond_with(@taxon_curator)
    respond_to do |format|
      format.html { redirect_to @taxon_curator.taxon }
      format.json { render json: @taxon_curator }
    end
  end

  def update
    @taxon_curator.update(taxon_curator_params)
    respond_to do |format|
      format.html { redirect_to @taxon_curator.taxon }
      format.json { render json: @taxon_curator }
    end
  end

  def destroy
    @taxon_curator.destroy
    respond_to do |format|
      format.html { redirect_to @taxon_curator.taxon }
      format.json { render json: @taxon_curator }
    end
  end

  private
    def set_taxon_curator
      @taxon_curator = TaxonCurator.find(params[:id])
    end

    def taxon_curator_params
      params.require(:taxon_curator).permit(:taxon_id, :user_id)
    end
end
