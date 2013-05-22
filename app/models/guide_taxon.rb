class GuideTaxon < ActiveRecord::Base
  attr_accessible :display_name, :guide_id, :name, :taxon_id, :taxon, :guide_photos_attributes, 
    :guide_sections_attributes, :guide_ranges_attributes
  belongs_to :guide, :inverse_of => :guide_taxa
  belongs_to :taxon
  has_many :guide_sections, :inverse_of => :guide_taxon, :dependent => :destroy
  has_many :guide_photos, :inverse_of => :guide_taxon, :dependent => :destroy
  has_many :guide_ranges, :inverse_of => :guide_taxon, :dependent => :destroy
  has_many :photos, :through => :guide_photos
  accepts_nested_attributes_for :guide_sections, :allow_destroy => true
  accepts_nested_attributes_for :guide_photos, :allow_destroy => true
  accepts_nested_attributes_for :guide_ranges, :allow_destroy => true
  before_save :set_names_from_taxon
  before_create :set_default_photo

  def set_names_from_taxon
    return true unless taxon
    self.name = taxon.name if name.blank?
    self.display_name = taxon.default_name.name if display_name.blank?
    true
  end

  def set_default_photo
    return true unless guide_photos.blank?
    return true if taxon.blank?
    return true if taxon.photos.blank?
    self.guide_photos.build(:photo => taxon.photos.first)    
    true
  end
end
