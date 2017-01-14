class TaxonRangesController < ApplicationController
  before_filter :curator_required
  
  def new
    @taxon_range = TaxonRange.new( taxon_id: params[:taxon_id].to_i )
  end
  
  def edit
    @taxon_range = TaxonRange.find( params[:id] )
  end
  
  def create
    @taxon_range = TaxonRange.new( params[:taxon_range] )

    respond_to do |format|
      if @taxon_range.save
        format.html do
          redirect_to(
            @taxon_range.taxon || taxa_path,
            notice: I18n.t( "taxon_range_created_notice" )
          )
        end
      else
        format.html { render action: "new" }
      end
    end
  end
  
  def update
    @taxon_range = TaxonRange.find( params[:id] )
    respond_to do |format|
      if @taxon_range.update_attributes( params[:taxon_range] )
        @taxon_range.taxon
        format.html do
          redirect_to(
            @taxon_range.taxon || taxa_path,
            notice: I18n.t( "taxon_range_updated_notice" )
          )
        end
      else
        format.html { render action: "edit" }
      end
    end
  end
  
  def destroy
    @taxon_range = TaxonRange.find( params[:id] )
    @taxon_range.destroy
    
    respond_to do |format|
      format.html { redirect_to( @taxon_range.taxon ) }
    end
  end
end
