class TaxonStage < TaxonChange
  
  def add_input_taxon(t)
  end

  def add_output_taxon(t)
    self.taxon = t
  end

  def commit_taxon_change
    self.committed_on = Time.now
    self.save
    end_taxon = self.taxon
    end_taxon.is_active = "true"
    end_taxon.save
  end
  
end