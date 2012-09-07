class WikimediaController < ApplicationController
  before_filter :return_here, :only => [:options]
  before_filter :login_required

  # Return an HTML fragment containing checkbox inputs for Wikimedia photos.
  # Params:
  #   taxon_id:        a taxon_id
  #   q:        a search param
  def photo_fields
    @photos = []
    taxon_id = params[:taxon_id]
    @taxon = Taxon.find_by_id(taxon_id)
    taxon_name = @taxon.name
    alt_taxon_name = params[:q]
    unless alt_taxon_name == ""
      taxon_name = alt_taxon_name
    end
    
    begin
      @photos = WikimediaPhoto.search_wikimedia_for_taxon(taxon_name)
    rescue
      @photos = []
    end
    
    render :partial => 'photos/photo_list_form', :locals => {
      :photos => @photos, 
      :index => params[:index],
      :local_photos => false }
  end
    
end
