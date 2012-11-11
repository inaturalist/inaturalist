class TaxonLink < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :user
  validates_format_of :url, :with => URI.regexp, 
    :message => "should look like a URL, e.g. http://inaturalist.org"
  validates_presence_of :taxon_id
  
  before_save :set_site_title
  
  scope :for_taxon, lambda {|taxon|
    where(
      "taxon_id = ? OR (show_for_descendent_taxa = TRUE and taxon_id IN (?))", 
      taxon, taxon.ancestors.map(&:id)
    )
  }
  
  TEMPLATE_TAGS = %w"[NAME] [GENUS] [SPECIES]"

  validate :url_can_only_have_name_or_genus_species
  validate :url_cant_have_genus_without_species
  validate :url_cant_have_species_without_genus
  
  def url_can_only_have_name_or_genus_species
    if url.to_s =~ /\[NAME\]/ && (url.to_s =~ /\[GENUS\]/ || url.to_s =~ /\[SPECIES\]/)
      self.errors.add(:url, "can only have [NAME] or [GENUS]/[SPECIES]")
    end
  end
  
  def url_cant_have_genus_without_species
    if !self.url.blank? && self.url =~ /\[GENUS\]/ && self.url !~ /\[SPECIES\]/
      self.errors.add(:url, "can't have [GENUS] without [SPECIES]")
    end
  end
  
  def url_cant_have_species_without_genus  
    if !self.url.blank? && self.url =~ /\[SPECIES\]/ && self.url !~ /\[GENUS\]/
      self.errors.add(:url, "can't have [SPECIES] without [GENUS]")
    end
  end
  
  # Fill in the template values for the URL given a taxon
  def url_for_taxon(taxon)
    new_url = self.url.sub('[NAME]', taxon.name)
    if taxon.species_or_lower? && pieces = taxon.name.split
      new_url.sub!('[GENUS]', pieces.first)
      new_url.sub!('[SPECIES]', pieces[1] || '')
    else
      new_url.sub!(/\[GENUS\].*\[SPECIES\]/, taxon.name)
    end
    new_url
  end
  
  def set_site_title
    if self.site_title.blank?
      self.site_title = URI.parse(url_without_template_tags).host
    end
  end
  
  def url_without_template_tags
    stripped_url = self.url
    TEMPLATE_TAGS.each {|tt| stripped_url.gsub!(tt, '')}
    stripped_url
  end
end
