class TaxonSplit < TaxonChange
  has_many :new_taxa, :through => :taxon_change_taxa, :source => :taxon
  
  def verb_phrase
    "split into"
  end
end
