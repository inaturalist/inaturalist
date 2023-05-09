class PlaceTaxonName < ApplicationRecord
  audited except: [:taxon_name_id, :place_id], associated_with: :taxon
  belongs_to :place, :inverse_of => :place_taxon_names
  belongs_to :taxon_name, :inverse_of => :place_taxon_names
  has_one :taxon, through: :taxon_name
  validates_uniqueness_of :place_id, :scope => :taxon_name_id
  validates_presence_of :place_id, :taxon_name

  before_create do |ptn|
    ptn.position = PlaceTaxonName.where( place: ptn.place ).joins(:taxon_name).
      where( "taxon_names.taxon_id = ?", ptn.taxon_name.taxon_id ).count + 1
  end

  def to_s
    "<PlaceTaxonName #{id}, place: #{place&.display_name} (#{place_id}), taxon_name: #{taxon_name&.to_s}>"
  end

  #
  # Create PlaceTaxonNames for matching countries. This helps people who
  # cannot choose a locale that matches a lexicon but can choose a place.
  #
  def self.create_country_records_from_lexicons(options = {})
    start = Time.now
    logger = options[:logger] || Rails.logger
    created = 0
    errors = 0
    mapping = options[:mapping] || {
      Japanese: [:Japan],
      German: [:Germany, :Austria],
      "Chinese Traditional" => ['Hong Kong', :Taiwan],
      "Chinese Simplified" => [:China]
    }
    mapping.each do |lexicon, country_names|
      countries = Place.where(admin_level: Place::COUNTRY_LEVEL, name: country_names).to_a
      TaxonName.joins("LEFT OUTER JOIN place_taxon_names ptn ON ptn.taxon_name_id = taxon_names.id").
          includes(:place_taxon_names).
          where("taxon_names.lexicon = ?", lexicon).find_each do |tn|
        # not a fan of the overselection and filter approach here, since we have a lot of names. Is there a way to do this in the db?
        candidate_countries = countries.select{|c| !tn.place_ids.include?(c.id)}
        next if candidate_countries.blank?
        candidate_countries.each do |country|
          ptn = PlaceTaxonName.new(taxon_name: tn, place: country)
          if ptn.save
            logger.info "Added #{tn} to #{country}"
            created += 1
          else
            logger.error "[ERROR] Failed to save #{ptn}: #{ptn.errors.full_messages.to_sentence}"
            errors += 1
          end
        end
      end
    end
    logger.info "Created #{created} PlaceTaxonName records, failed on #{errors} (#{Time.now - start}s)"
  end

  def as_indexed_json(options={})
    {
      place_id: place_id,
      position: position
    }
  end

end
