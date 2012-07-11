class TaxonMerge < TaxonChange
  has_many :old_taxa, :through => :taxon_change_taxa, :source => :taxon
  
  def self.update_observations_later(taxon_change_id)
    unless taxon_merge = TaxonMerge.find_by_id(taxon_change_id)
      return
    end
    taxon_merge.update_observations
  end
  
  def update_observations
    Observation.update_all(["taxon_id = ?", taxon_id], ["taxon_id IN (?)", old_taxon_ids])
  end

end