class TaxonMerge < TaxonChange
  has_many :old_taxa, :through => :taxon_change_taxa, :source => :taxon
  
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
    [taxon].compact
  end

  def output_taxon
    taxon
  end

  def verb_phrase
    "merged into"
  end

  def commit
    input_taxa.each do |input_taxon|
      #duplicate photos
      input_taxon.taxon_photos.sort_by(&:id).each do |taxon_photo|
        begin
          output_taxon.photos << taxon_photo.photo
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[ERROR #{Time.now}] Failed to add #{taxon_photo} to #{output_taxon}: #{e}"
        end
      end
      
      #duplicate taxon_names
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
      
      #duplicate colors
      output_taxon.colors << input_taxon.colors if output_taxon.colors.blank?

      # Move input child taxa to the output taxon
      input_taxon.children.each { |child| child.move_to_child_of( output_taxon ) }
    end
    super
  end
  
end