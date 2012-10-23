class TaxonMerge < TaxonChange
  has_many :old_taxa, :through => :taxon_change_taxa, :source => :taxon
  
  def commit_taxon_change
    self.committed_on = Time.now
    self.save
    end_taxon = self.taxon
    self.old_taxa.each do |start_taxon|
      start_taxon.is_active = "false"
      start_taxon.save
      
      #duplicate photos
      start_taxon.photos.each {|photo| photo.taxa << end_taxon}
      
      #duplicate taxon_names
      start_taxon.taxon_names.all.each do |taxon_name|
        taxon_name.reload
        unless taxon_name.valid?
          Rails.logger.info "[INFO] Destroying #{taxon_name} while committing taxon change " +
            "#{self.id}: #{taxon_name.errors.full_messages.to_sentence}"
          taxon_name.destroy
          next
        end
        new_taxon_name = taxon_name.dup
        new_taxon_name.taxon_id = end_taxon.id
        new_taxon_name.is_valid = false if taxon_name.is_scientific_names? && taxon_name.is_valid?
        new_taxon_name.save
      end
      
      #duplicate colors
      end_taxon.colors << start_taxon.colors if end_taxon.colors.blank?
      
      #send_updates(start_taxon)
    end
    end_taxon.is_active = "true"
    end_taxon.save
  end
  
end