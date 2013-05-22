class WikimediaCommonsController < ApplicationController
  before_filter :return_here, :only => [:options]
  before_filter :authenticate_user!

  # Return an HTML fragment containing checkbox inputs for Wikimedia Commons photos.
  # Params:
  #   taxon_id:        a taxon_id
  #   q:        a search param
  def photo_fields
    @photos = []
    taxon_id = params[:taxon_id]
    @taxon = Taxon.find_by_id(taxon_id)
    name = params[:q].blank? ? @taxon.try(:name) : params[:q]
    
    @photos = WikimediaCommonsPhoto.search_wikimedia_for_taxon(name, 
      :page => params[:page], 
      :per_page => params[:per_page], 
      :limit => params[:limit]
    ) || []
    @photos = @photos.compact
    
    render :partial => 'photos/photo_list_form', :locals => {
      :photos => @photos, 
      :index => params[:index],
      :local_photos => false }
  end
    
end
