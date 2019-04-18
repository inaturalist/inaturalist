class TaxonStage < TaxonChange

  validate :has_no_inputs

  def has_no_inputs
    errors.add(:base, "cannot have inputs") if taxa.size > 0
  end
  
  def add_input_taxon(t)
  end

  def input_taxa
    []
  end

  def add_output_taxon(t)
    self.taxon = t
  end

  def output_taxa
    [taxon].compact
  end

  def commit_records( options = {} )
    nil
  end
  
end