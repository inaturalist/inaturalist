class TaxonFramework < ActiveRecord::Base
  belongs_to :taxon, inverse_of: :taxon_framework
  belongs_to :source
  belongs_to :user
  has_updater
  has_many :taxon_framework_relationships, dependent: :destroy
  has_many :taxon_curators, inverse_of: :taxon_framework, dependent: :destroy
  
  before_save :check_taxon_framework_relationships
  before_save :check_taxon_curators
  after_save :check_other_taxon_framework_relationships
  after_save :handle_change_in_completeness
  
  accepts_nested_attributes_for :source
  validate :rank_level_below_taxon_rank
  validates :taxon_id, presence: true

  attr_accessor :skip_reindexing_taxa
  attr_accessor :skip_check_frameworks
  attr_accessor :skip_check_curators
  
  def handle_change_in_completeness
    # would use new_record? here if this was called any time other than after_save
    return true unless complete_changed? || ( rank_level_changed? && !id_changed? )
    return true if skip_reindexing_taxa
    Taxon.
      delay( priority: INTEGRITY_PRIORITY, unique_hash: { "Taxon::reindex_taxa_covered_by": self.id } ).
      reindex_taxa_covered_by( self )
    true
  end
  
  def check_taxon_framework_relationships
    return true if skip_check_frameworks
    return true if new_record?
    return true if rank_level_was.nil? || source_id_was.nil?
    return true unless rank_level_changed? || source_id_changed? || taxon_id_changed?
    taxon_framework_relationships.destroy_all
    true
  end
  
  def check_other_taxon_framework_relationships
    return true if skip_check_frameworks
    return true unless rank_level
    return true unless new_record? || rank_level_changed? || source_id_changed? || taxon_id_changed?
    
    upstream_taxon_frameworks = TaxonFramework.where( "taxon_id IN (?)", taxon.ancestor_ids ).pluck( :id )
    ancestor_string = taxon.rank == "stateofmatter" ? taxon.id.to_s : "%/#{ taxon.id }"
    tr = TaxonFrameworkRelationship.joins( :taxa ).where( "taxon_framework_id IN (?) AND (taxa.id = ? OR taxa.ancestry LIKE (?) OR taxa.ancestry LIKE (?))", upstream_taxon_frameworks, taxon.id, "#{ ancestor_string }", "#{ ancestor_string }/%" )
    return tr.destroy_all
  end
  
  def check_taxon_curators
    return true if skip_check_curators
    return true if new_record?
    return true if rank_level_was.nil?
    return true unless rank_level_changed? && rank_level.nil?
    taxon_curators.destroy_all
    true
  end
  
  def rank_level_below_taxon_rank
    return  true if rank_level.nil?
    if rank_level.to_i > taxon.rank_level.to_i
      errors.add( :rank_level, "must be below the taxon rank" )
    end
    true
  end
  
  def covers?
    return true unless rank_level.nil?
    return false
  end

  def get_downstream_taxon_frameworks_count
    return false unless covers?
    ancestry_string = taxon.rank == "stateofmatter" ? "#{ taxon_id }" : "%/#{ taxon_id }"
    downstream_taxon_frameworks = TaxonFramework.includes( "taxon" ).joins( "JOIN taxa ON taxon_frameworks.taxon_id = taxa.id" ).
      where( "( taxa.ancestry LIKE ( '#{ ancestry_string }/%' ) OR taxa.ancestry LIKE ( '#{ ancestry_string }' ) ) AND taxa.rank_level > #{ rank_level } AND taxon_frameworks.rank_level IS NOT NULL" )
    .count
  end
  
  def get_downstream_taxon_frameworks
    return false unless covers?
    ancestry_string = taxon.rank == "stateofmatter" ? "#{ taxon_id }" : "%/#{ taxon_id }"
    downstream_taxon_frameworks = TaxonFramework.includes( "taxon" ).joins( "JOIN taxa ON taxon_frameworks.taxon_id = taxa.id" ).
      where( "( taxa.ancestry LIKE ( '#{ ancestry_string }/%' ) OR taxa.ancestry LIKE ( '#{ ancestry_string }' ) ) AND taxa.rank_level > #{ rank_level } AND taxon_frameworks.rank_level IS NOT NULL" ).
      order("taxa.rank_level desc").limit(30)
  end
  
  def get_unassigned_taxa
    ancestry_string = taxon.rank == "stateofmatter" ? "#{ taxon_id }" : "#{ taxon.ancestry }/#{ taxon_id }"
    other_taxon_frameworks = TaxonFramework.joins( :taxon ).
      where( "( taxa.ancestry LIKE ( '#{ ancestry_string }/%' ) OR taxa.ancestry LIKE ( '#{ ancestry_string }' ) )" ).
      where( "taxa.rank_level > #{ rank_level } AND taxon_frameworks.rank_level IS NOT NULL" )

    other_taxon_frameworks_taxa = ( other_taxon_frameworks.count > 0 ) ?
      Taxon.where( id: other_taxon_frameworks.map( &:taxon_id ) ) : []

    unassigned_taxa = Taxon.
      joins( "JOIN taxa parent ON parent.id = (string_to_array(taxa.ancestry, '/')::int[])[array_upper(string_to_array(taxa.ancestry, '/')::int[],1)]" ).
      where( "parent.id = #{taxon_id} OR parent.ancestry = ? OR parent.ancestry LIKE ?", ancestry_string, "#{ancestry_string}/%" ).
      where( is_active: true ).
      where( "parent.rank_level > ? ", rank_level ).
      where( "taxa.rank_level < ? ", rank_level ).
      where( "( select count(*) from conservation_statuses ct where ct.taxon_id=taxa.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0" )

    other_taxon_frameworks_taxa.each do |t|
      unassigned_taxa = unassigned_taxa.where( "parent.ancestry != ? AND parent.ancestry NOT LIKE ?", "#{ t.ancestry }/#{ t.id }", "#{ t.ancestry }/#{ t.id }/%" )
    end

    return unassigned_taxa
  end
  
  def get_internal_taxa_covered_by_taxon_framework
    ancestry_string = taxon.rank == "stateofmatter" ?
      "#{ taxon_id }" : "#{ taxon.ancestry }/#{ taxon.id }"
    other_taxon_frameworks = TaxonFramework.joins(:taxon).
      where( "( taxa.ancestry LIKE ( '#{ ancestry_string }/%' ) OR taxa.ancestry LIKE ( '#{ ancestry_string }' ) )" ).
      where( "taxa.rank_level > #{ rank_level } AND taxon_frameworks.rank_level IS NOT NULL" )

    other_taxon_frameworks_taxa = ( other_taxon_frameworks.count > 0 ) ?
      Taxon.where(id: other_taxon_frameworks.map(&:taxon_id)) : []

    internal_taxa = Taxon.
      where( "taxa.ancestry = ? OR taxa.ancestry LIKE ?", ancestry_string, "#{ancestry_string}/%" ).
      where( is_active: true ).
      joins( "JOIN taxa parent ON parent.id = (string_to_array(taxa.ancestry, '/')::int[])[array_upper(string_to_array(taxa.ancestry, '/')::int[],1)]" ).
      where( "taxa.rank_level >= ? ", rank_level).
      where("( select count(*) from conservation_statuses ct where ct.taxon_id=taxa.id AND ct.iucn=70 AND ct.place_id IS NULL ) = 0")

    other_taxon_frameworks_taxa.each do |t|
      internal_taxa = internal_taxa.where("taxa.ancestry != ? AND taxa.ancestry NOT LIKE ?", "#{t.ancestry}/#{t.id}", "#{t.ancestry}/#{t.id}/%")
    end

    return internal_taxa
  end
  
  
  def get_flagged_taxa_count(options = {})
    taxon_clause = ""
    if t = options[:taxon]
      taxon_clause = " AND ( taxa.id = #{ t.id } OR taxa.ancestry = '#{ t.ancestry }/#{ t.id }' OR taxa.ancestry LIKE '#{ t.ancestry }/#{ t.id }/%' )"
    end
    flagged_taxa_count = Taxon.get_internal_taxa_covered_by( self ).
      joins( "INNER JOIN flags ON taxa.id = flags.flaggable_id AND flags.flaggable_type = 'Taxon'" ).
      where( "flags.resolved = false#{taxon_clause}").count

    return flagged_taxa_count
  end
  
  def get_flagged_taxa(options = {})
    taxon_clause = ""
    if t = options[:taxon]
      taxon_clause = " AND ( taxa.id = #{ t.id } OR taxa.ancestry = '#{ t.ancestry }/#{ t.id }' OR taxa.ancestry LIKE '#{ t.ancestry }/#{ t.id }/%' )"
    end
    flagged_taxa = Taxon.get_internal_taxa_covered_by( self ).
      joins( "INNER JOIN flags ON taxa.id = flags.flaggable_id AND flags.flaggable_type = 'Taxon'" ).
      where( "flags.resolved = false#{taxon_clause}").order( "taxa.rank_level desc" ).limit( 10 )

    return flagged_taxa
  end
  
  def taxon_framework_taxon_name
    taxon.name
  end
  
  # attempting this through the UI will destroy relevant taxon_framework_relationships
  # here's a way to rather move them accordingly
  def self.bud_off_child_taxon_framework( taxon_id )
    return false unless taxon = Taxon.find(taxon_id)
    return false unless parent_taxon_framework = taxon.get_upstream_taxon_framework
    ancestry = [taxon.ancestor_ids, taxon_id].join( "/" )
    tf = TaxonFramework.new(
      taxon_id: taxon_id,
      rank_level: parent_taxon_framework.rank_level,
      source_id: parent_taxon_framework.source_id,
      user_id: parent_taxon_framework.user_id
    )
    tf.skip_check_frameworks = true
    return false unless tf.save
    tfrs = TaxonFrameworkRelationship.joins( :taxa ).where( "taxon_framework_id = ? AND ( taxa.ancestry = '#{ancestry}' OR taxa.ancestry LIKE '#{ancestry}/%' )", parent_taxon_framework.id )
    tfrs.update_all( taxon_framework_id: tf.id )
    true
  end
  
end
