# frozen_string_literal: true

class TaxonSwap < TaxonChange
  has_many :old_taxa, through: :taxon_change_taxa, source: :taxon

  validate :only_has_one_input
  validate :has_inputs_and_outputs

  def only_has_one_input
    errors.add( :base, I18n.t( :taxon_swap_only_has_one_input ) ) if input_taxa.size > 1
  end

  def has_inputs_and_outputs
    return unless input_taxa.empty? || output_taxa.empty?

    errors.add( :base, I18n.t( :taxon_swap_has_inputs_and_outputs ) )
  end

  def old_taxon
    old_taxa.first
  end

  def opposite_taxon_from( subject_taxon )
    if subject_taxon.id == taxon_id
      taxa.loaded? ? taxa.first : old_taxon
    else
      taxon
    end
  end

  def add_input_taxon( adding_input_taxon )
    taxon_change_taxa.build( taxon: adding_input_taxon, taxon_change: self )
  end

  def add_output_taxon( adding_output_taxon )
    self.taxon = adding_output_taxon
  end

  def input_taxa
    taxon_change_taxa.reject( &:_destroy ).map( &:taxon ).compact
  end

  def output_taxa
    [taxon].compact
  end

  def input_taxon
    taxon_change_taxa.reject( &:_destroy ).first.try( :taxon )
  end

  def output_taxon
    taxon
  end

  def verb_phrase
    "replaced with"
  end

  def commit
    super
    # duplicate photos
    input_taxon.taxon_photos.sort_by( &:id ).each do | taxon_photo |
      begin
        output_taxon.photos << taxon_photo.photo
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "[ERROR #{Time.now}] Failed to add #{taxon_photo} to #{output_taxon}: #{e}"
      end
    end

    # duplicate conservation_statuses
    input_taxon.conservation_statuses.each do | cs |
      new_cs = cs.dup
      new_cs.taxon_id = output_taxon.id
      unless new_cs.save
        Rails.logger.error "[ERROR #{Time.now}] TaxonChange #{id} failed to duplicate #{cs}: " +
          new_cs.errors.full_messages.to_sentence
      end
    end

    # duplicate taxon_names
    input_taxon.taxon_names.each do | taxon_name |
      taxon_name.reload
      unless taxon_name.valid?
        Rails.logger.info "[INFO] Destroying #{taxon_name} while committing taxon change " \
          "#{id}: #{taxon_name.errors.full_messages.to_sentence}"
        taxon_name.destroy
        next
      end
      new_taxon_name = taxon_name.dup
      new_taxon_name.creator = nil
      new_taxon_name.updater = nil
      if new_taxon_name.source_url.blank?
        new_taxon_name.source_url = UrlHelper.edit_taxon_name_url( taxon_name )
      end
      if new_taxon_name.source_identifier.blank?
        new_taxon_name.source_identifier = taxon_name.id
      end
      new_taxon_name.taxon_id = output_taxon.id
      new_taxon_name.is_valid = false if taxon_name.is_scientific_names? && taxon_name.is_valid?
      if new_taxon_name.save
        taxon_name.place_taxon_names.each do | place_taxon_name |
          new_place_taxon_name = place_taxon_name.dup
          new_place_taxon_name.taxon_name_id = new_taxon_name.id
          new_place_taxon_name.save
        end
      else
        Rails.logger.error "[ERROR #{Time.now}] TaxonChange #{id} failed to duplicate #{taxon_name}: " +
          new_taxon_name.errors.full_messages.to_sentence
      end
    end

    # duplicate taxon_range
    if output_taxon.taxon_range.nil? && ( taxon_range = input_taxon.taxon_range )
      new_taxon_range = taxon_range.dup
      new_taxon_range.taxon_id = output_taxon.id
      unless new_taxon_range.save
        Rails.logger.error "[ERROR #{Time.now}] TaxonChange #{id} failed to duplicate #{taxon_range}: " +
          new_taxon_range.errors.full_messages.to_sentence
      end
      unless new_taxon_range.create_kml_attachment
        Rails.logger.error "[ERROR #{Time.now}] TaxonChange #{id} failed to duplicate #{taxon_range} attachment: " +
          new_taxon_range.errors.full_messages.to_sentence
      end
    end

    # duplicate atlas
    if !output_taxon.atlas && ( atlas = input_taxon.atlas )
      new_atlas = atlas.dup
      new_atlas.taxon_id = output_taxon.id
      unless new_atlas.save
        Rails.logger.error "[ERROR #{Time.now}] Atlas #{id} failed to duplicate #{atlas}: " +
          new_atlas.errors.full_messages.to_sentence
      end
    end

    # duplicate colors
    output_taxon.colors << input_taxon.colors if output_taxon.colors.blank?

    # Move input child taxa to the output taxon
    delay( priority: USER_PRIORITY ).move_input_children_to_output( input_taxon.id )
  end
end
