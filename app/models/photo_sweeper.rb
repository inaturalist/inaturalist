class PhotoSweeper < ActionController::Caching::Sweeper
  begin
    observe Photo
  rescue ActiveRecord::NoDatabaseError
    puts "Database not connected, failed to observe Photo. Ignore if setting up for the first time"
  end
  include Shared::SweepersModule
  
  def after_update(photo)
    photo.taxa.each do |taxon|
      expire_taxon(taxon)
    end
  end
end
