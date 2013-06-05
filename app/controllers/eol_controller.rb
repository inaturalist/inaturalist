class EolController < ApplicationController
  before_filter :return_here, :only => [:options]
  before_filter :authenticate_user!

  # Return an HTML fragment containing checkbox inputs for EOL photos.
  # Params:
  #   taxon_id:        a taxon_id
  #   q:        a search param
  def photo_fields
    @photos = []
    @q = if !params[:q].blank?
      params[:q]
    elsif taxon_id = params[:taxon_id]
      @taxon = Taxon.find_by_id(taxon_id)
      @taxon.name
    end
    
    limit = params[:limit]
    limit = 36 if limit.blank? || limit.to_i > 36
    @photos = EolPhoto.search_eol(@q, :limit => limit)
    
    render :partial => 'photos/photo_list_form', :locals => {
      :photos => @photos, 
      :index => params[:index],
      :local_photos => false }
  end
    
end
