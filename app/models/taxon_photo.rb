class TaxonPhoto < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :photo
  
  after_create :expire_caches
  after_destroy :destroy_orphan_photo
  after_destroy :unfeature_taxon
  after_destroy :expire_caches
  
  validates_associated :photo
  
  def destroy_orphan_photo
    Photo.send_later(:destroy_orphans, photo_id)
    true
  end
  
  def unfeature_taxon
    return true if taxon.featured_at.blank?
    taxon.update_attribute(:featured_at, nil) if taxon.taxon_photos.count == 0
    true
  end
  
  def expire_caches
    Rails.cache.delete(taxon.photos_cache_key)
    Rails.cache.delete(taxon.photos_with_external_cache_key)
    true
  end
  
end
