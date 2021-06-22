class TaxonPhotosController < ApplicationController
  before_action :admin_required
  layout "bootstrap"

  def new
    @taxon = Taxon.find_by_id( params[:taxon_id] )
    @taxon_photo = TaxonPhoto.new( taxon: @taxon )
  end

  def create
    @taxon_photo = TaxonPhoto.new( params[:taxon_photo] )
    if params[:file]
      @photo = LocalPhoto.new( file: params[:file], user: current_user )
      @photo.save
      @taxon_photo.photo = @photo
    end
    if @taxon_photo.save
      flash[:notice] = "Saved new taxon photos"
    else
      flash[:error] = "Failed to save taxon photo: #{@taxon_photo.errors.full_messages.to_sentence}"
    end
    redirect_to( edit_taxon_path( @taxon_photo.taxon_id ) )
  end
end
