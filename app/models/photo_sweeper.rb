class PhotoSweeper < ActionController::Caching::Sweeper
  observe Photo
  include Shared::SweepersModule
  
  def after_update(photo)
    photo.taxa.each do |taxon|
      expire_taxon(taxon)
    end
  end
end
