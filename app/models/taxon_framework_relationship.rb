class TaxonFrameworkRelationship < ApplicationRecord
  alias_attribute :internal_taxa, :taxa
  
  attr_accessor :current_user
  
  belongs_to :user
  has_updater
  belongs_to :taxon_framework
  has_many :external_taxa, dependent: :destroy
  has_many :taxa, before_add: :check_if_covered, dependent: :nullify
  
  accepts_nested_attributes_for :external_taxa, allow_destroy: true
  accepts_nested_attributes_for :taxa
  
  before_save :set_relationship
  before_validation :mark_external_taxa_for_destruction 
  
  validates :taxon_framework, presence: true
  validate :taxon_framework_has_source
  
  RELATIONSHIPS = [
    "match",
    "alternate_position",
    "one_to_one",
    "many_to_many",
    "many_to_one",
    "one_to_many",
    "not_external",
    "not_internal"
  ]
  
  INTERNAL_TAXON_JOINS = [
    "LEFT OUTER JOIN taxa t ON t.taxon_framework_relationship_id = taxon_framework_relationships.id"
  ]
  EXTERNAL_TAXON_JOINS = [
    "LEFT OUTER JOIN external_taxa et ON et.taxon_framework_relationship_id = taxon_framework_relationships.id"
  ]
  
  scope :relationships, lambda { |relationships| where( "taxon_framework_relationships.relationship IN (?)", relationships ) }
  scope :taxon_framework, lambda{ |taxon_framework| where("taxon_framework_relationships.taxon_framework_id = ?", taxon_framework ) }
  scope :by, lambda{ |user| where( user_id: user ) }
  scope :active, -> {
    joins( INTERNAL_TAXON_JOINS ).
    where( "t.is_active = true" )
  }
  scope :inactive, -> {
    joins( INTERNAL_TAXON_JOINS ).
    where( "t.is_active = false" )
  }
  scope :internal_rank, lambda { |rank|
    joins( INTERNAL_TAXON_JOINS ).
    where( "t.rank = ?", rank )
  }
  scope :external_rank, lambda { |rank|
    joins( EXTERNAL_TAXON_JOINS ).
    where( "et.rank = ?", rank )
  }
  scope :internal_taxon, lambda{ |taxon|
    joins( INTERNAL_TAXON_JOINS ).
    where( "t.id = ? OR t.ancestry LIKE (?) OR t.ancestry LIKE (?)", taxon.id, "%/#{ taxon.id }", "%/#{ taxon.id }/%")
  }
  scope :external_taxon, lambda{ |taxon_name|
    joins( EXTERNAL_TAXON_JOINS ).
    where( "lower(et.name) = ? OR lower(et.parent_name) = ?", taxon_name.downcase.strip, taxon_name.downcase.strip)
  }
  
  def mark_external_taxa_for_destruction
    external_taxa.each do |external_taxon|
      if external_taxon.name.blank?
        external_taxon.mark_for_destruction
      end
    end
  end
    
  def taxon_framework_has_source
    unless taxon_framework && taxon_framework.source_id.present?
      errors.add :taxon_framework_id, "taxon framework must have source"
    end
  end
  
  def taxa_covered_by_taxon_framework
    return false unless taxa.map{ |t| t.parent.id == taxon_framework.taxon_id || taxon.upstream_taxon_framework.id == taxon_framework.id }.all?
    true
  end
  
  def check_if_covered(taxon)
    unless taxon.id.nil? || taxon.rank.nil?
      raise if taxon.ancestry.nil?
      raise unless taxon.parent.id == taxon_framework.taxon_id || taxon.upstream_taxon_framework.id == taxon_framework.id
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
         external_taxa.first.parent_rank.downcase == taxa.first.parent.rank
        self.relationship = "match"
      elsif external_taxa.first.name == taxa.first.name && 
         external_taxa.first.rank == taxa.first.rank
        self.relationship = "alternate_position"
      else
        self.relationship = "one_to_one"
      end
    elsif external_taxa_count > 1 && taxa_count > 1
      self.relationship = "many_to_many"
    elsif external_taxa_count == 1 && taxa_count > 1
      self.relationship = "many_to_one"
    elsif external_taxa_count > 1 && taxa_count == 1
      self.relationship = "one_to_many"
    elsif external_taxa_count == 0 && taxa_count >= 1
      self.relationship = "not_external"
    elsif external_taxa_count >= 1 && taxa_count == 0
      self.relationship = "not_internal"
    else
      self.relationship = "error"
    end
    true
  end
  
  def as_json
    internal_taxa = self.internal_taxa.map{ |it| 
        { name: it.name, rank: it.rank, parent_name: it.parent.name, parent_rank: it.parent.rank, url: it.id }
    }
    if it_root = ( internal_taxa.map{ |it| it[:parent_name] + "_" + it[:parent_rank] }.uniq - internal_taxa.map{ |it| it[:name] + "_" + it[:rank] }.uniq )[0]
      internal_taxa.unshift( { name: it_root.split( "_" )[0], rank: it_root.split( "_" )[1] } )
    else
      internal_taxa.unshift( { name: nil, rank: nil } )
    end
    external_taxa = self.external_taxa.map{ |et| 
      { name: et.name, rank: et.rank, parent_name: et.parent_name, parent_rank: et.parent_rank, url: et.url }
    }
    if et_root = ( external_taxa.map{ |et| et[:parent_name] + "_" + et[:parent_rank] }.uniq - external_taxa.map{ |et| et[:name] + "_" + et[:rank] }.uniq)[0]
      external_taxa.unshift( { name:  et_root.split( "_" )[0], rank: et_root.split( "_" )[1] } )
    else
      external_taxa.unshift( { name: nil, rank: nil } )
    end
    if external_taxa.count == 1 && external_taxa[0][:name].nil? && external_taxa[0][:rank].nil?
      if it_root
        external_taxa[0] = { name: it_root.split( "_" )[0], rank: it_root.split( "_" )[1] }
      end
    end
    if internal_taxa.count == 1 && internal_taxa[0][:name].nil? && internal_taxa[0][:rank].nil?
      if et_root
        internal_taxa[0] = { name:  et_root.split( "_" )[0], rank: et_root.split( "_" )[1] }
      end
    end
    {
      internal_taxa: internal_taxa,
      external_taxa: external_taxa
    }
  end
  
end
