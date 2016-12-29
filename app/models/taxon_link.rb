class TaxonLink < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :user
  belongs_to :place
  validates_format_of :url, :with => URI.regexp, :message => "should look like a URL, e.g. http://www.inaturalist.org"
  validates_presence_of :taxon_id, :site_title
  validates_length_of :short_title, :maximum => 10, :allow_blank => true
  
  before_validation :set_site_title
  
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
    true
  end
  
  def url_without_template_tags
    stripped_url = self.url
    TEMPLATE_TAGS.each {|tt| stripped_url.gsub!(tt, '')}
    stripped_url
  end

  def self.by_taxon(taxon, options = {})
    return [] if taxon.blank?
    taxon_links = if taxon.species_or_lower?
      # fetch all relevant links
      TaxonLink.for_taxon(taxon).includes(:taxon).to_a
    else
      # fetch links without species only
      TaxonLink.for_taxon(taxon).where(:species_only => false).includes(:taxon).to_a
    end
    tl_place_ids = taxon_links.map(&:place_id).compact
    if !tl_place_ids.blank?
      if options[:reject_places]
        taxon_links.reject! {|tl| tl.place_id}
      else
        # fetch listed taxa for this taxon with places matching the links
        place_listed_taxa = ListedTaxon.where("place_id IN (?)", tl_place_ids).where(:taxon_id => taxon)

        # remove links that have a place_id set but don't have a corresponding listed taxon
        taxon_links.reject! do |tl|
          tl.place_id && place_listed_taxa.detect{|lt| lt.place_id == tl.place_id}.blank?
        end
      end
    end
    taxon_links.uniq!{|tl| tl.url}
    taxon_links.sort_by{|tl| tl.taxon.ancestry || ''}.reverse
  end
end
