class GuideTaxon < ActiveRecord::Base
  attr_accessor :html
  attr_accessible :display_name, :guide_id, :name, :taxon_id, :taxon, :guide_photos_attributes, 
    :guide_sections_attributes, :guide_ranges_attributes, :html, :position
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
  before_create :set_default_section

  validates_uniqueness_of :taxon_id, :scope => :guide_id

  scope :in_taxon, lambda {|taxon| 
    taxon = Taxon.find_by_id(taxon.to_i) unless taxon.is_a? Taxon
    return where("1 = 2") unless taxon
    c = taxon.descendant_conditions
    c[0] = "taxa.id = #{taxon.id} OR #{c[0]}"
    joins(:taxon).where(c)
  }

  scope :dbsearch, lambda {|q| where("guide_taxa.name ILIKE ? OR guide_taxa.display_name ILIKE ?", "%#{q}%", "%#{q}%")}

  def default_guide_photo
    guide_photos.sort_by(&:position).first
  end

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

  def set_default_section
    return true if taxon.blank?
    return true unless guide_sections.blank?
    return true if taxon.wikipedia_summary.blank?
    self.guide_sections.build(
      :title => "Summary", 
      :description => taxon.wikipedia_summary,
      :rights_holder => "Wikipedia",
      :license => Observation::CC_BY_SA,
      :source_url => TaxonDescribers::Wikipedia.page_url(taxon)
    )
    true
  end
end
