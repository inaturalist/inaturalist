class TaxonSplit < TaxonChange
  has_many :new_taxa, :through => :taxon_change_taxa, :source => :taxon
  
  def commit_taxon_change
    self.committed_on = Time.now
    self.save
    
    start_taxon = tc.taxon
    start_taxon.is_active = "false"
    
    tc.new_taxa.each do |end_taxon|
      end_taxon.is_active = "true"
      end_taxon.save  
    end
    start_taxon.save
    #send_updates(start_taxon)
  end
  
end
