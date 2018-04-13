class ObservationFieldValue < ActiveRecord::Base

  blockable_by lambda {|ofv| ofv.observation.try(:user_id) }
  
  belongs_to :observation, :inverse_of => :observation_field_values
  belongs_to :observation_field
  belongs_to :user
  belongs_to :updater, :class_name => 'User'
  has_one :annotation
  
  before_validation :strip_value
  before_validation :set_user
  after_create :create_annotation
  after_destroy :destroy_annotation
  after_update :fix_annotation_after_update
  validates_uniqueness_of :observation_field_id, :scope => :observation_id
  # I'd like to keep this, but since mobile clients could be submitting
  # observations that weren't created on a mobile device now, the check really
  # needs to happen in the controller... but not sure how best to do that
  # validates_presence_of :value, :if => lambda {|ofv| ofv.observation && !ofv.observation.mobile? }
  validates_presence_of :observation_field_id
  validates_presence_of :observation
  validates_presence_of :user
  validates_length_of :value, :maximum => 2048
  # validate :validate_observation_field_datatype, :if => lambda {|ofv| ofv.observation }
  # Again, we can't support this until all mobile clients support all field types
  validate :validate_observation_field_allowed_values
  validate :observer_prefers_fields_by_user

  after_save :update_observation_field_counts, :index_observation

  notifies_subscribers_of :observation, :notification => "activity",
    :on => :save,
    :include_owner => lambda {|ofv, observation|
      ofv.updater_id != observation.user_id
    },
    :if => lambda {|ofv, observation, subscription|
      return true if subscription.user_id == observation.user_id || ofv.user_id != ofv.updater_id
      false
    }
  auto_subscribes :user, :to => :observation, :if => lambda {|record, subscribable| 
    record.user_id != subscribable.user_id
  }

  attr_accessor :updater_user_id

  include Shared::TouchesObservationModule
  include ActsAsUUIDable
  
  LAT_LON_REGEX = /#{Observation::COORDINATE_REGEX},#{Observation::COORDINATE_REGEX}/

  scope :datatype, lambda {|datatype| joins(:observation_field).where("observation_fields.datatype = ?", datatype)}
  scope :field, lambda {|field|
    field = if field.is_a?(ObservationField)
      field
    elsif field.to_i > 0
      ObservationField.find_by_id(field)
    else
      ObservationField.where("lower(name) = ?", field.to_s.downcase).first
    end
    # includes(:observation_field).where("observation_fields.name = ?", datatype)
    where(:observation_field_id => field.try(:id))
  }
  scope :license, lambda {|license|
    scope = joins(:observation)
    if license == 'none'
      scope.where("observations.license IS NULL")
    elsif Observation::LICENSE_CODES.include?(license)
      scope.where("observations.license = ?", license)
    else
      scope.where("observations.license IS NOT NULL")
    end
  }

  scope :quality_grade, lambda {|quality_grade|
    scope = joins(:observation)
    quality_grade = '' unless Observation::QUALITY_GRADES.include?(quality_grade)
    scope.where("observations.quality_grade = ?", quality_grade)
  }

  def to_s
    "<ObservationFieldValue #{id}, observation_field_id: #{observation_field_id}, observation_id: #{observation_id}>"
  end

  def taxon
    return nil unless observation_field.datatype == ObservationField::TAXON
    @taxon ||= Taxon.find_by_id(value)
  end

  def taxon=(taxon)
    @taxon = taxon
  end
  
  def strip_value
    self.value = value.to_s.strip unless value.nil?
  end

  def set_user
    if updater_user_id
      self.user_id ||= updater_user_id
      self.updater_id = updater_user_id
    elsif observation
      self.user_id ||= observation.user_id
      self.updater_id ||= user_id
    end
    true
  end
  
  def validate_observation_field_datatype
    return true if observation.mobile? # HACK until we implement ui for *all* observation field types in the mobile apps
    case observation_field.datatype
    when "numeric"
      errors.add(:value, "must be a number") if value !~ Observation::FLOAT_REGEX
    when "location"
      errors.add(:value, "must decimal latitude and decimal longitude separated by a comma") if value !~ LAT_LON_REGEX
    when "date"
      unless value =~ /^\d{4}\-\d{2}\-\d{2}$/
        errors.add(:value, :date_format, 
          :observation_field_name => observation_field.name,
          :observation_species_guess => observation.try(:species_guess)
        )
      end
    when "datetime"
      begin
        Time.iso8601(value)
      rescue ArgumentError => e
        errors.add(:value, :datetime_format,
          :observation_field_name => observation_field.name,
          :observation_species_guess => observation.try(:species_guess)
        )
      end
    when "time"
      begin
        Time.parse(value)
        if value !~ /^\d\d:\d\d/
          errors.add(:value, :time_format, 
            :observation_field_name => observation_field.name,
            :observation_species_guess => observation.try(:species_guess)
          )
        end
      rescue ArgumentError => e
        errors.add(:value, :time_format, 
          :observation_field_name => observation_field.name,
          :observation_species_guess => observation.try(:species_guess)
        )
      end
    when "dna"
      if value =~ /[^ATCG\s]/
        errors.add(:value, :dna_only_atcg)
      end
    end
  end
  
  def validate_observation_field_allowed_values
    return true if observation_field.allowed_values.blank?
    values = observation_field.allowed_values.split('|').map(&:downcase)
    unless values.include?(value.to_s.downcase)
      errors.add(:value, 
        "of #{observation_field.name} must be #{values[0..-2].map{|v| "#{v}, "}.join}or #{values.last}.")
    end
  end

  def observer_prefers_fields_by_user
    return true unless user && observation
    return true if observation.user.preferred_observation_fields_by === User::PREFERRED_OBSERVATION_FIELDS_BY_ANYONE
    if observation.user.preferred_observation_fields_by === User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER
      if observation.user_id != user_id
        errors.add(:observation_id, :user_does_not_accept_fields_from_others )
      end
    elsif observation.user.preferred_observation_fields_by === User::PREFERRED_OBSERVATION_FIELDS_BY_CURATORS
      unless user.is_curator?
        errors.add(:observation_id, :user_only_accepts_fields_from_site_curators )
      end
    end
    true
  end

  def update_observation_field_counts
    observation_field.update_counts
  end

  def index_observation
    observation.try( :elastic_index! )
  end

  def create_annotation
    attr_val = annotation_attribute_and_value
    return if attr_val.blank?
    Annotation.create!(observation_field_value: self,
      resource: observation,
      controlled_attribute: attr_val[:controlled_attribute],
      controlled_value: attr_val[:controlled_value],
      user_id: user_id,
      created_at: created_at) rescue nil
  end

  def annotation_attribute_and_value
    return unless observation
    return unless observation_field.datatype == "text"
    stripped_value = value.strip.downcase
    if ControlledTerm::VALUES_TO_MIGRATE[stripped_value.to_sym]
      controlled_attribute = ControlledTerm.first_term_by_label(
        ControlledTerm::VALUES_TO_MIGRATE[stripped_value.to_sym].to_s.tr("_", " "))
      controlled_value = ControlledTerm.first_term_by_label(stripped_value)
    elsif ( observation_field.name =~ /phenology/i && value =~ /^flower(s|ing)?$/i ) ||
          ( observation_field.name == "Plant flowering" && value == "Yes" )
      controlled_attribute = ControlledTerm.first_term_by_label("Plant Phenology")
      controlled_value = ControlledTerm.first_term_by_label("Flowering")
    elsif observation_field.name =~ /phenology/i && value =~ /fruit(s|ing)?$/i &&
          value !~ /[0-9]/
      controlled_attribute = ControlledTerm.first_term_by_label("Plant Phenology")
      controlled_value = ControlledTerm.first_term_by_label("Fruiting")
    end
    return unless controlled_attribute && controlled_value
    { controlled_attribute: controlled_attribute,
      controlled_value: controlled_value }
  end

  def destroy_annotation
    return unless annotation && annotation.vote_score <= 0
    annotation.destroy
  end

  def fix_annotation_after_update
    if annotation && annotation.vote_score <= 0
      annotation.destroy
      create_annotation
    end
  end

  def as_indexed_json(options={})
    json = {
      id: id,
      uuid: uuid,
      field_id: observation_field.id,
      datatype: observation_field.datatype,
      name: observation_field.name,
      name_ci: observation_field.name,
      value: self.value,
      value_ci: self.value,
      user_id: user_id
    }
    json[:taxon_id] = value if observation_field.datatype == ObservationField::TAXON
    json
  end

  def self.update_for_taxon_change( taxon_change, options, &block )
    input_taxon_ids = taxon_change.input_taxa.map(&:id)
    scope = ObservationFieldValue.joins( :observation_field ).
      where( "observation_fields.datatype = ?", ObservationField::TAXON )
    scope = scope.where(
      input_taxon_ids.map {|itid| "observation_field_values.value = '#{itid}'" }.join( " OR " )
    )
    scope = scope.where( user_id: options[:user] ) if options[:user]
    scope = scope.where( "observation_field_values.id IN (?)", options[:records] ) unless options[:records].blank?
    scope = scope.where( options[:conditions] ) if options[:conditions]
    scope = scope.includes( options[:include] ) if options[:include]
    obs_ids = Set.new
    scope.find_each do |ofv|
      next unless output_taxon = taxon_change.output_taxon_for_record( ofv )
      ofv.update_attributes( value: output_taxon.id )
      obs_ids << ofv.observation_id
    end
    Observation.elastic_index!( ids: obs_ids.to_a )
  end

end
