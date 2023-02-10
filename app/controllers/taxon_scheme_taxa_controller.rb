class TaxonSchemeTaxaController < ApplicationController
  before_action :authenticate_user!, :except => [:index, :show]
  before_action :curator_required, :except => [:index, :show]
    
  def new
    @taxon_schemes = TaxonScheme.limit(100).sort_by{|ts| ts.title}
    @taxon = Taxon.find(params[:taxon_id]) unless params[:taxon_id].blank?
    @taxon_name = TaxonName.where(:taxon_id => @taxon.id, :lexicon => "Scientific Names", :is_valid => true).first if @taxon
    @taxon_scheme_taxon = TaxonSchemeTaxon.new(
      :taxon => @taxon, 
      :taxon_name => @taxon_name
    )
  end
  
  def create
    @taxon_scheme_taxon = TaxonSchemeTaxon.new(params[:taxon_scheme_taxon])
    
    respond_to do |format|
      if @taxon_scheme_taxon.save
        flash[:notice] = "Your taxon scheme taxon was saved."
        format.html { redirect_to taxon_schemes_path(@taxon_scheme_taxon.taxon) }
      else
        format.html { render :action => "new" }
      end
    end
  end
  
  def edit
    @taxon_schemes = TaxonScheme.limit(100).sort_by{|ts| ts.title}
    @taxon_scheme_taxon = TaxonSchemeTaxon.find(params[:id])
    @taxon = Taxon.find_by_id(@taxon_scheme_taxon.taxon_id)
  end
  
  def update
    @taxon_scheme_taxon = TaxonSchemeTaxon.find(params[:id])
    respond_to do |format|
      if @taxon_scheme_taxon.update(params[:taxon_scheme_taxon])
        flash[:notice] = 'Taxon scheme taxon was successfully updated.'
        format.html { redirect_to(taxon_schemes_path(@taxon_scheme_taxon.taxon)) }
      else
        format.html { render :action => 'edit' }
      end
    end
  end
  
  def destroy
    @taxon_scheme_taxon = TaxonSchemeTaxon.find(params[:id])
    if @taxon_scheme_taxon.destroy
      flash[:notice] = "Taxon scheme taxon was deleted."
    else
      flash[:error] = "Something went wrong deleting the taxon scheme taxon '#{@taxon_scheme_taxon.id}'!"
    end
    respond_to do |format|
      format.html { redirect_to(taxon_schemes_path(@taxon_scheme_taxon.taxon)) }
    end
  end
  
end