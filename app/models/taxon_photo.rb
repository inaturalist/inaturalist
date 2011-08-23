class TaxonPhoto < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :photo
  
  after_destroy :destroy_orphan_photo
  after_destroy :unfeature_taxon
  
  def destroy_orphan_photo
    Photo.send_later(:destroy_orphans, photo_id)
    true
  end
  
  def unfeature_taxon
    return true if taxon.featured_at.blank?
    taxon.update_attribute(:featured_at, nil) if taxon.taxon_photos.count == 0
    true
  end
  
end
