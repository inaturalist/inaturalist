class TaxonSplit < TaxonChange
  has_many :new_taxa, :through => :taxon_change_taxa, :source => :taxon
  
  def self.update_observations_later(taxon_change_id)
    unless taxon_split = TaxonSplit.find_by_id(taxon_change_id)
      return
    end
    taxon_split.update_observations
  end
  
  def update_observations
    new_taxa.each do |new_taxon|
      taxon_range = TaxonRange.without_geom.first(:conditions => ["taxon_id = ?", new_taxon])
      unless taxon_range
        Rails.logger.error "[ERROR #{Time.now}] Failed to split observations of #{taxon} into #{new_taxon}: new taxon has no range"
        next
      end
      ids = Observation.of(taxon).in_taxon_range(taxon_range).all(:select => "id").map{|o| o.id}
      Observation.update_all(["taxon_id = ?", taxon_id], ["id IN (?)", ids])
    end
  end

end