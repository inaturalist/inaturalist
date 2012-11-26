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
    self.taxon_change_taxa.build(:taxon => t, :taxon_change => self)
  end

  def add_output_taxon(t)
    self.taxon = t
  end

  def input_taxa
    taxa
  end

  def output_taxa
    [taxon]  
  end

  def input_taxon
    taxa.first
  end

  def output_taxon
    taxon
  end

  def verb_phrase
    "replaced with"
  end
  
  def commit
    # duplicate photos
    input_taxon.taxon_photos.sort_by(&:id).each do |taxon_photo|
      begin
        output_taxon.photos << taxon_photo.photo
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "[ERROR #{Time.now}] Failed to add #{taxon_photo} to #{output_taxon}: #{e}"
      end
    end
    
    # duplicate iucn_status
    output_taxon.conservation_status = input_taxon.conservation_status
    output_taxon.conservation_status_source_id = input_taxon.conservation_status_source_id
    output_taxon.conservation_status_source_identifier = input_taxon.conservation_status_source_identifier
    
    # duplicate taxon_names
    input_taxon.taxon_names.each do |taxon_name|
      taxon_name.reload
      unless taxon_name.valid?
        Rails.logger.info "[INFO] Destroying #{taxon_name} while committing taxon change " +
          "#{self.id}: #{taxon_name.errors.full_messages.to_sentence}"
        taxon_name.destroy
        next
      end
      new_taxon_name = taxon_name.dup
      new_taxon_name.taxon_id = output_taxon.id
      new_taxon_name.is_valid = false if taxon_name.is_scientific_names? && taxon_name.is_valid?
      unless new_taxon_name.save
        Rails.logger.error "[ERROR #{Time.now}] TaxonChange #{id} failed to duplicate #{taxon_name}: " + 
          new_taxon_name.errors.full_messages.to_sentence
      end
    end
    
    # duplicate taxon_range
    if output_taxon.taxon_ranges.count == 0
      input_taxon.taxon_ranges.each do |taxon_range|
        new_taxon_range = taxon_range.dup
        new_taxon_range.taxon_id = output_taxon.id
        unless new_taxon_range.save
          Rails.logger.error "[ERROR #{Time.now}] TaxonChange #{id} failed to duplicate #{taxon_range}: " +
            new_taxon_range.errors.full_messages.to_sentence
        end
      end
    end
    
    # duplicate colors
    output_taxon.colors << input_taxon.colors if output_taxon.colors.blank?
    
    super
  end
  
end
