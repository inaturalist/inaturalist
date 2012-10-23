class TaxonDrop < TaxonChange
  
  def commit_taxon_change
    self.committed_on = Time.now
    self.save
    start_taxon = self.taxon
    start_taxon.is_active = "false"
    start_taxon.save
    #send_updates(start_taxon) #send update indicating taxon inactivated to everyone who's observed/identified/listed it
  end
  
end