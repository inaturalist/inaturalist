class TaxonMerge < TaxonChange
 has_many :old_taxa, :through => :taxon_change_taxa, :source => :taxon
 
end