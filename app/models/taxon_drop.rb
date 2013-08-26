class TaxonDrop < TaxonChange

  validate :has_no_outputs

  def has_no_outputs
    errors.add(:base, "cannot have outputs") if taxa.size > 0
  end
  
  def add_output_taxon(t)
  end

  def output_taxa
    []
  end
  
end