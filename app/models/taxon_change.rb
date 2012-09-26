class TaxonChange < ActiveRecord::Base
  belongs_to :taxon
  has_many :taxon_change_taxa, :dependent => :destroy
  has_many :taxa, :through => :taxon_change_taxa
  belongs_to :source
  has_many :comments, :as => :parent, :dependent => :destroy
  belongs_to :user
  
  validates_presence_of :taxon_id
  accepts_nested_attributes_for :source
  accepts_nested_attributes_for :taxon_change_taxa
  
  TAXON_JOINS = [
    "LEFT OUTER JOIN taxon_change_taxa tct ON tct.taxon_change_id = taxon_changes.id",
    "LEFT OUTER JOIN taxa t1 ON taxon_changes.taxon_id = t1.id",
    "LEFT OUTER JOIN taxa t2 ON tct.taxon_id = t2.id"
  ]

  TYPES = %w(TaxonChange TaxonMerge TaxonSplit TaxonSwap TaxonDrop TaxonStage)
  
  scope :types, lambda {|types| where("type IN (?)", types)}
  scope :committed, where("committed_on IS NOT NULL")
  scope :uncommitted, where("committed_on IS NULL")
  scope :change_group, lambda{|group| where("change_group = ?", group)}
  scope :iconic_taxon, lambda{|iconic_taxon|
    joins(TAXON_JOINS).
    where("t1.iconic_taxon_id = ? OR t2.iconic_taxon_id = ?", iconic_taxon, iconic_taxon)
  }
  scope :source, lambda{|source|
    joins(TAXON_JOINS).
    where("t1.source_id = ? OR t2.source_id = ?", source, source)
  }
  
  scope :taxon, lambda{|taxon|
    joins(TAXON_JOINS).
    where("t1.id = ? OR t2.id = ?", taxon, taxon)
  }
  
  scope :input_taxon, lambda{|taxon|
    joins(TAXON_JOINS).
    where(
      "(taxon_changes.type IN ('TaxonSwap', 'TaxonMerge') AND t2.id = ?) OR " +
      "(taxon_changes.type IN ('TaxonSplit', 'TaxonDrop', 'TaxonStage') AND taxon_changes.taxon_id = ?)", 
      taxon, taxon
    )
  }
  
  scope :output_taxon, lambda{|taxon|
    joins(TAXON_JOINS).
    where(
      "(taxon_changes.type IN ('TaxonSwap', 'TaxonMerge') AND taxon_changes.taxon_id = ?) OR " +
      "(taxon_changes.type = 'TaxonSplit' AND t2.id = ?)", 
      taxon, taxon
    )
  }
  
  scope :taxon_scheme, lambda{|taxon_scheme|
    joins(TAXON_JOINS).
    joins(
      "LEFT OUTER JOIN taxon_scheme_taxa tst1 ON tst1.taxon_id = t1.id",
      "LEFT OUTER JOIN taxon_scheme_taxa tst2 ON tst2.taxon_id = t2.id",
      "LEFT OUTER JOIN taxon_schemes ts1 ON ts1.id = tst1.taxon_scheme_id",
      "LEFT OUTER JOIN taxon_schemes ts2 ON ts2.id = tst2.taxon_scheme_id"
    ).
    where("ts1.id = ? OR ts2.id = ?", taxon_scheme, taxon_scheme)
  }
  
  def to_s
    "<#{self.class} #{id}>"
  end
  
  def committed?
    !committed_on.blank?
  end
  
  def self.commit_taxon_change(taxon_change_id)
    unless taxon_change = TaxonChange.find_by_id(taxon_change_id)
      return
    end
    unless taxon_change.committed_on.nil?
      return
    end
    TaxonChange.update_all(["committed_on = ?", Time.now],["id = ?", taxon_change.id])
    case taxon_change.class.name when 'TaxonSplit'
      Taxon.update_all({:is_active => false},["id = ?", taxon_change.taxon_id])
      Taxon.update_all({:is_active => true},["id in (?)", taxon_change.taxon_change_taxa.map{|tct| tct.taxon_id}])
      TaxonSplit.delay(:priority => 2).update_observations_later(taxon_change.id)
    when 'TaxonMerge'
      Taxon.update_all({:is_active => false},["id in (?)", taxon_change.taxon_change_taxa.map{|tct| tct.taxon_id}])
      Taxon.update_all({:is_active => true},["id = ?", taxon_change.taxon_id])
      TaxonMerge.delay(:priority => 2).update_observations_later(taxon_change.id)
    when 'TaxonSwap'
      Taxon.update_all({:is_active => false},["id in (?)", taxon_change.taxon_change_taxa.map{|tct| tct.taxon_id}])
      Taxon.update_all({:is_active => true},["id = ?", taxon_change.taxon_id])
      TaxonSwap.delay(:priority => 2).update_observations_later(taxon_change.id)
    when 'TaxonDrop'
      Taxon.update_all({:is_active => false},["id = ?", taxon_change.taxon_id])
    when 'TaxonStage'
      Taxon.update_all({:is_active => true},["id = ?", taxon_change.taxon_id])
    end
  end

end
