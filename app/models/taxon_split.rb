class TaxonSplit < TaxonChange
  has_many :new_taxa, :through => :taxon_change_taxa, :source => :taxon
  validate :has_more_than_one_output

  def has_more_than_one_output
    unless taxon_change_taxa.size > 1
      errors.add( :base, "must have more than one output taxon" )
    end
  end
  
  def verb_phrase
    "split into"
  end
end
