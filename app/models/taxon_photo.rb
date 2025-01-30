# frozen_string_literal: true

class TaxonPhoto < ApplicationRecord
  acts_as_elastic_model lifecycle_callbacks: [:destroy]

  audited except: [:taxon_id], associated_with: :taxon

  belongs_to :taxon
  belongs_to :photo
  
  after_create :expire_caches
  after_destroy :destroy_orphan_photo
  after_destroy :unfeature_taxon
  after_destroy :expire_caches

  after_save :index_taxon
  after_destroy :index_taxon
  
  validates_associated :photo
  validates_uniqueness_of :photo_id, :scope => [:taxon_id], :message => "has already been added to that taxon"
  validate :reasonable_number_of_photos, on: :create
  validate :photo_cannot_have_unresolved_flags

  attr_accessor :skip_taxon_indexing

  MAX_TAXON_PHOTOS = 12

  def reasonable_number_of_photos
    if taxon && taxon.taxon_photos.count >= MAX_TAXON_PHOTOS
      errors.add( :taxon, :too_many_photos, max: MAX_TAXON_PHOTOS )
    end
  end

  def photo_cannot_have_unresolved_flags
    return unless photo&.flags&.any? {| f | !f.resolved? }

    errors.add( :photo, :cannot_have_unresolved_flags )
  end

  def to_s
    "<TaxonPhoto #{id} taxon_id: #{taxon_id} photo_id: #{photo_id}>"
  end
  
  def destroy_orphan_photo
    Photo.delay(:priority => INTEGRITY_PRIORITY).destroy_orphans(photo_id)
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

  def index_taxon
    return if skip_taxon_indexing
    taxon.elastic_index!
    Taxon.delay( priority: INTEGRITY_PRIORITY ).index_taxa( taxon.ancestor_ids )
    true
  end

end
