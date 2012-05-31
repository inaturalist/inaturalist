class EolController < ApplicationController
  before_filter :return_here, :only => [:options]
  before_filter :login_required

  # Return an HTML fragment containing checkbox inputs for EOL photos.
  # Params:
  #   taxon_id:        a taxon_id
  def photo_fields
    @photos = []
    taxon_id = params[:taxon_id]
    @taxon = Taxon.find_by_id(taxon_id)
    begin
       @photos << EolPhoto.new_from_taxon_name(@taxon.name)
    rescue
      @photos = []
    end
    
    render :partial => 'photos/photo_list_form', :locals => {
      :photos => @photos, 
      :index => params[:index],
      :local_photos => false }
  end
    
end
