class TaxonMerge < TaxonChange
 has_many :old_taxa, :through => :taxon_change_taxa, :source => :taxon
 
 def update_observations
   Observation.update_all(["taxon_id = ?", taxon_id], ["taxon_id IN (?)", old_taxon_ids])
 end
 
end