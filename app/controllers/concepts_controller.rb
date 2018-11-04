class ConceptsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  before_action :set_concept
  
  layout "bootstrap"
  
  def new
    @rank_levels = prepare_rank_levels
    if (taxon_id = params['taxon_id']).present?
      @concept = Concept.new(taxon_id: taxon_id)
    else
      @concept = Concept.new
    end
  end
  
  def edit
    @rank_levels = prepare_rank_levels
  end
  
  def create
    @concept = Concept.new(concept_params)
    if @concept.save
      redirect_to taxonomy_details_for_taxon_path(@concept.taxon)
    else
      render action: :new
    end
  end
  
  def update
    if @concept.update_attributes(concept_params)
      redirect_to taxonomy_details_for_taxon_path(@concept.taxon)
    else
      render action: :edit
    end
  end
  
  def destroy
    @concept.destroy
    flash[:notice] = "concept deleted"
    redirect_to taxonomy_details_for_taxon_path(@concept.taxon)
  end
  
  private
  
  def prepare_rank_levels
    rank_levels = Taxon::RANK_LEVELS
    ["genushybrid","hybrid","variety","form","infrahybrid"].each do |r|
      rank_levels.delete(r)
    end
    return rank_levels
  end
  
  def set_concept
    @concept = Concept.where(id: params[:id]).includes(
            {taxon: [:taxon_names, :photos, :taxon_ranges_without_geom, :taxon_schemes]},
            :source
          ).first
  end
   
  def concept_params
    params.require(:concept).permit(:description, :taxon_id, :rank_level, :complete, :source_id, source_attributes: [:id, :in_text, :citation, :url, :title, :user_id])
  end
  
end