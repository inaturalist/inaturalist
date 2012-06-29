class TaxonSwap < TaxonChange
 has_one :old_taxa, :through => :taxon_change_taxa, :source => :taxon
 
end