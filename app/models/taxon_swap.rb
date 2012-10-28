class TaxonSwap < TaxonChange
  has_many :old_taxa, :through => :taxon_change_taxa, :source => :taxon
  
  def old_taxon
    old_taxa.first
  end
  
  def opposite_taxon_from(subject_taxon)
    if subject_taxon.id == taxon_id
      taxa.loaded? ? taxa.first : old_taxon
    else
      taxon
    end
  end

  def add_input_taxon(t)
    self.taxon_change_taxa.build(:taxon => t)
  end

  def add_output_taxon(t)
    self.taxon = t
  end
  
  def commit_taxon_change
    self.committed_on = Time.now
    self.save
    end_taxon = self.taxon
    start_taxon = self.old_taxon
    start_taxon.is_active = "false"
    start_taxon.save
    
    #duplicate photos
    start_taxon.photos.each {|photo| photo.taxa << end_taxon}
    
    #duplicate iucn_status
    end_taxon.conservation_status = start_taxon.conservation_status
    end_taxon.conservation_status_source_id = start_taxon.conservation_status_source_id
    end_taxon.conservation_status_source_identifier = start_taxon.conservation_status_source_identifier
    
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
    
    #duplicate taxon_range
    start_taxon.taxon_ranges.each do |taxon_range|
      new_taxon_range = taxon_range.dup
      new_taxon_range.taxon_id = end_taxon.id
      new_taxon_range.save
    end
    
    #duplicate colors
    end_taxon.colors << start_taxon.colors if end_taxon.colors.blank?
    
    #send_updates(start_taxon)
    
    end_taxon.is_active = "true"
    end_taxon.save
  end
  
end
