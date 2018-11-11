class TaxonFrameworksController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  before_action :set_taxon_framework
  
  layout "bootstrap"
  
  def new
    @rank_levels = prepare_rank_levels
    if (taxon_id = params['taxon_id']).present?
      @taxon_framework = TaxonFramework.new(taxon_id: taxon_id)
    else
      @taxon_framework = TaxonFramework.new
    end
  end
  
  def edit
    @rank_levels = prepare_rank_levels
  end
  
  def create
    @taxon_framework = TaxonFramework.new(taxon_framework_params)
    if @taxon_framework.save
      redirect_to taxonomy_details_for_taxon_path(@taxon_framework.taxon)
    else
      render action: :new
    end
  end
  
  def update
    if @taxon_framework.update_attributes(taxon_framework_params)
      redirect_to taxonomy_details_for_taxon_path(@taxon_framework.taxon)
    else
      render action: :edit
    end
  end
  
  def destroy
    @taxon_framework.destroy
    flash[:notice] = "taxon framework deleted"
    redirect_to taxonomy_details_for_taxon_path(@taxon_framework.taxon)
  end
  
  private
  
  def prepare_rank_levels
    rank_levels = Taxon::RANK_FOR_RANK_LEVEL.invert
  end
  
  def set_taxon_framework
    @taxon_framework = TaxonFramework.where(id: params[:id]).includes(
            {taxon: [:taxon_names, :photos, :taxon_ranges_without_geom, :taxon_schemes]},
            :source
          ).first
  end
   
  def taxon_framework_params
    params.require(:taxon_framework).permit(:description, :taxon_id, :rank_level, :complete, :source_id, source_attributes: [:id, :in_text, :citation, :url, :title, :user_id])
  end
  
end