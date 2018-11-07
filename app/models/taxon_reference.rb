class TaxonReference < ActiveRecord::Base
  belongs_to :user
  belongs_to :concept
  has_many :external_taxa, dependent: :destroy
  has_many :taxa, before_add: :check_if_covered, dependent: :nullify
  
  accepts_nested_attributes_for :external_taxa, allow_destroy: true
  accepts_nested_attributes_for :taxa
  
  before_save :set_relationship
  before_validation :mark_external_taxa_for_destruction 
  
  validates :concept, presence: true
  validate :concept_has_source
  
  RELATIONSHIPS = [
    'match',
    'swap',
    'position_swap',
    'many_to_many',
    'lump',
    'split',
    'not_in_reference',
    'not_local',
    'unknown'
  ]
  
  TAXON_JOINS = [
    "LEFT OUTER JOIN taxa t ON t.taxon_reference_id = taxon_references.id"
  ]
  
  scope :relationships, lambda {|relationships| where("taxon_references.relationship IN (?)", relationships)}
  scope :concept, lambda{|concept| where("taxon_references.concept_id = ?", concept)}
  scope :by, lambda{|user| where(:user_id => user)}
  scope :active, -> {
    joins(TAXON_JOINS).
    where("t.is_active = true")
  }
  scope :inactive, -> {
    joins(TAXON_JOINS).
    where("t.is_active = false")
  }
  scope :rank, lambda {|rank|
    joins(TAXON_JOINS).
    where("t.rank = ?", rank)
  }
  scope :taxon, lambda{|taxon|
    joins(TAXON_JOINS).
    where("t.id = ? OR t.ancestry LIKE (?) OR t.ancestry LIKE (?)", taxon.id, "%/#{taxon.id}", "%/#{taxon.id}/%")
  }
  
  def mark_external_taxa_for_destruction
    external_taxa.each do |external_taxon|
      if external_taxon.name.blank?
        external_taxon.mark_for_destruction
      end
    end
  end
  
  def concept_has_source
    errors.add :concept_id, "concept must have source" unless concept.source_id.present?
  end
  
  def taxa_covered_by_concept
    return false unless taxa.map{|t| t.parent.id == concept.taxon_id || t.parent.is_internode_of(concept)}.all?
    true
  end
  
  def check_if_covered(taxon)
    unless taxon.id.nil? || taxon.rank.nil?
      raise if taxon.ancestry.nil?
      raise unless taxon.parent.id == concept.taxon_id || taxon.parent.is_internode_of(concept)
    end
    true
  end
  
  def set_relationship
    external_taxa_count = external_taxa.count
    taxa_count = taxa.count
    if external_taxa_count == 1 && taxa_count == 1
      if external_taxa.first.name == taxa.first.name && 
         external_taxa.first.rank == taxa.first.rank &&
         external_taxa.first.parent_name == taxa.first.parent.name &&
         external_taxa.first.parent_rank == taxa.first.parent.rank
        self.relationship = "match"
      elsif external_taxa.first.name == taxa.first.name && 
         external_taxa.first.rank == taxa.first.rank
        self.relationship = "position swap"
      else
        self.relationship = "swap"
      end
    elsif external_taxa_count > 1 && taxa_count > 1
      self.relationship = "many to many"
    elsif external_taxa_count > 1 && taxa_count == 1
      self.relationship = "lump"
    elsif external_taxa_count == 1 && taxa_count > 1
      self.relationship = "split"
    elsif external_taxa_count == 0 && taxa_count == 1
      self.relationship = "not in reference"
    elsif external_taxa_count == 1 && taxa_count == 0
      self.relationship = "not local"
    else
      self.relationship = "unknown"
    end
    true
  end
  
end
