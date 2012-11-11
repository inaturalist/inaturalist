class TaxonChangeTaxaController < ApplicationController
  
  def new
    @taxon_change = TaxonChange.find(params[:taxon_change_id])
    @taxon_change_taxon = TaxonChangeTaxon.new(:taxon_change => @taxon_change)
  end
  
  def create
    @taxon_change_taxon = TaxonChangeTaxon.new(params[:taxon_change_taxon])
    
    respond_to do |format|
      if @taxon_change_taxon.save
        flash[:notice] = "Your taxon change taxon was saved."
        format.html { redirect_to taxon_change_path(@taxon_change_taxon.taxon_change) }
      else
        format.html { render :action => "new" }
      end
    end
  end
  
  def edit
    @taxon_change = TaxonChange.find(params[:taxon_change])
    @taxon_change_taxon = TaxonChangeTaxon.find(params[:taxon_change_taxon])
  end
  
  def update
     @taxon_change_taxon = TaxonChangeTaxon.find(params[:id])
    respond_to do |format|
      if @taxon_change_taxon.update_attributes(params[:taxon_change_taxon])
        flash[:notice] = 'Taxon change taxon was successfully updated.'
        format.html { redirect_to(taxon_change_path(@taxon_change_taxon.taxon_change)) }
      else
        format.html { render :action => 'edit' }
      end
    end
  end
  
  def destroy
    @taxon_change_taxon = TaxonChangeTaxon.find(params[:id])
    if @taxon_change_taxon.destroy
      flash[:notice] = "Taxon change taxon was deleted."
    else
      flash[:error] = "Something went wrong deleting the taxon change taxon '#{@taxon_change_taxon.id}'!"
    end
    respond_to do |format|
      format.html { redirect_to(taxon_change_path(@taxon_change_taxon.taxon_change)) }
    end
  end
  
end