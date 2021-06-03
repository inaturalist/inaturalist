class ObservationFieldValue < ActiveRecord::Base

  blockable_by lambda {|ofv| ofv.observation.try(:user_id) }
  
  belongs_to :observation, :inverse_of => :observation_field_values
  belongs_to :observation_field
  belongs_to :user
  has_updater
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
    return true unless observation_field.datatype === ObservationField::TEXT
    values = observation_field.allowed_values.split('|').map(&:downcase)
    unless values.include?(value.to_s.downcase)
      errors.add(:value, 
        "of #{observation_field.name} must be #{values[0..-2].map{|v| "#{v}, "}.join}or #{values.last}.")
    end
  end

  def observer_prefers_fields_by_user
    return true unless observation
    return true if observation.user.preferred_observation_fields_by === User::PREFERRED_OBSERVATION_FIELDS_BY_ANYONE
    if observation.user.preferred_observation_fields_by === User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER
      creator_is_not_observer = observation.user_id != user_id
      updater_is_not_observer = observation.user_id != updater_id
      if ( new_record? && creator_is_not_observer ) || ( persisted? && updater_is_not_observer )
        errors.add( :observation_id, :user_does_not_accept_fields_from_others )
      end
    elsif observation.user.preferred_observation_fields_by === User::PREFERRED_OBSERVATION_FIELDS_BY_CURATORS
      creation_by_non_observer_non_curator = new_record? && user_id != observation.user_id && !user&.is_curator?
      update_by_non_observer_non_curator = updater_id != observation.user_id && !updater&.is_curator?
      if creation_by_non_observer_non_curator || update_by_non_observer_non_curator
        errors.add( :observation_id, :user_only_accepts_fields_from_site_curators )
      end
    end
    true
  end

  def update_observation_field_counts
    observation_field.delay(
      priority: USER_PRIORITY,
      run_at: 30.minutes.from_now,
      unique_hash: { "ObservationField::update_counts" => observation_field.id }
    ).update_counts
  end

  def index_observation
    return if observation.skip_indexing
    return if observation.new_record?
    observation.wait_for_index_refresh ||= !!wait_for_obs_index_refresh
    observation.try( :elastic_index! )
  end

  def create_annotation
    attr_val = annotation_attribute_and_value
    return if attr_val.blank?
    a = Annotation.create(
      observation_field_value: self,
      resource: observation,
      controlled_attribute: attr_val[:controlled_attribute],
      controlled_value: attr_val[:controlled_value],
      user_id: user_id,
      created_at: created_at
    )
    unless a.persisted?
      Rails.logger.error "[ERROR] Failed to created annotation for #{self}: #{a.errors.full_messages.to_sentence}"
    end
    a
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
      controlled_attribute = ControlledTerm.first_term_by_label( "Plant Phenology" )
      controlled_value = ControlledTerm.first_term_by_label( "Flowering" )
    elsif observation_field.name =~ /phenology/i && value =~ /fruit(s|ing)?$/i &&
          value !~ /[0-9]/
      controlled_attribute = ControlledTerm.first_term_by_label( "Plant Phenology" )
      controlled_value = ControlledTerm.first_term_by_label( "Fruiting" )
    elsif ( observation_field.name =~ /life stage/i && value == "teneral" ) ||
          ( observation_field.name.downcase == "teneral" && value.downcase == "yes" )
      controlled_attribute = ControlledTerm.first_term_by_label( "Life Stage" )
      controlled_value = ControlledTerm.first_term_by_label( "Teneral" )
    elsif ( observation_field.name =~ /dead or alive/i ||
            observation_field.name =~ /alive( or |\/)dead/i ||
            observation_field.name =~ /was it alive/i ||
            observation_field.name =~ /alive \(aor\), dead \(dor\)/i )
      value_term_label = case value.downcase
      when "yes", "alive", "aor"
        "Alive"
      when "no", "dead", "dor"
        "Dead"
      when "maybe", "not sure", "unknown"
        "Cannot Be Determined"
      end
      return unless value_term_label
      controlled_attribute = ControlledTerm.first_term_by_label( "Alive or Dead" )
      controlled_value = ControlledTerm.first_term_by_label( value_term_label )
    elsif observation_field.name.downcase == "roadkill" && value == "yes"
      controlled_attribute = ControlledTerm.first_term_by_label( "Alive or Dead" )
      controlled_value = ControlledTerm.first_term_by_label( "Dead" )
    elsif observation_field.name =~ /animal sign/i
      value_term_label = case value.downcase
      when "tracks"
        "track"
      when "scat"
        "scat"
      when "bone", "bones"
        "bone"
      when "fur/feathers"
        "feather"
      when "shed skin"
        "molt"
      end
      return unless value_term_label
      controlled_attribute = ControlledTerm.first_term_by_label( "Evidence of Presence" )
      controlled_value = ControlledTerm.first_term_by_label( value_term_label )
    elsif observation_field.name.downcase === "scat/excreta" && value.downcase == "yes"
      controlled_attribute = ControlledTerm.first_term_by_label( "Evidence of Presence" )
      controlled_value = ControlledTerm.first_term_by_label( "scat" )
    elsif observation_field.name.downcase === "scat?" && value.downcase == "yes"
      controlled_attribute = ControlledTerm.first_term_by_label( "Evidence of Presence" )
      controlled_value = ControlledTerm.first_term_by_label( "scat" )
    elsif observation_field.name.downcase === "bone(s)" && value.downcase == "yes"
      controlled_attribute = ControlledTerm.first_term_by_label( "Evidence of Presence" )
      controlled_value = ControlledTerm.first_term_by_label( "bone" )
    elsif observation_field.name.downcase === "tracks" && value.downcase == "yes"
      controlled_attribute = ControlledTerm.first_term_by_label( "Evidence of Presence" )
      controlled_value = ControlledTerm.first_term_by_label( "track" )
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
    # make sure taxon_id is an integer
    if observation_field.datatype == ObservationField::TAXON && value.to_s =~ /\A[+-]?\d+\Z/
      json[:taxon_id] = value
    end
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
      next if !taxon_change.automatable_for_output?( output_taxon.id )
      ofv.update_attributes( value: output_taxon.id )
      obs_ids << ofv.observation_id
    end
    Observation.elastic_index!( ids: obs_ids.to_a )
  end

end
