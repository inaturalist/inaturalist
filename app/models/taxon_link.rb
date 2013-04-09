class TaxonLink < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :user
  belongs_to :place
  validates_format_of :url, :with => URI.regexp, 
    :message => "should look like a URL, e.g. #{CONFIG.site_url}"
  validates_presence_of :taxon_id
  
  before_save :set_site_title
  
  scope :for_taxon, lambda {|taxon|
    if taxon.species_or_lower?
      where(
        "taxon_id = ? OR (show_for_descendent_taxa = TRUE AND taxon_id IN (?))", 
        taxon, taxon.ancestor_ids
      )
    else
      where(
        "(show_for_descendent_taxa = ? AND species_only = ? AND taxon_id IN (?)) OR (show_for_descendent_taxa = FALSE AND taxon_id = ?)",
        true, false, [taxon.ancestor_ids, taxon.id].flatten, taxon
      )
    end
  }
  
  TEMPLATE_TAGS = %w"[NAME] [GENUS] [SPECIES] [RANK] [NAME_WITH_RANK]"
  
  validate :url_cant_have_genus_without_species
  validate :url_cant_have_species_without_genus

  def to_s
    "<TaxonLink #{id} taxon_id: #{taxon_id}, place_id: #{place_id}, user_id: #{user_id}>"
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
    new_url = url.sub('[NAME]', taxon.name)
    new_url = new_url.sub('[RANK]', taxon.rank)
    new_url = new_url.sub('[NAME_WITH_RANK]', taxon.name_with_rank)
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
