class TaxonStage < TaxonChange
  
  def add_input_taxon(t)
  end

  def input_taxa
    []
  end

  def add_output_taxon(t)
    self.taxon = t
  end

  def output_taxa
    [taxon]
  end
  
end