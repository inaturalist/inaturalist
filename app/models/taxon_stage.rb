class TaxonStage < TaxonChange
  
  def commit_taxon_change
    self.committed_on = Time.now
    self.save
    end_taxon = self.taxon
    end_taxon.is_active = "true"
    end_taxon.save
  end
  
end