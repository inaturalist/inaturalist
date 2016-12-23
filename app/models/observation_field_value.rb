class ObservationFieldValue < ActiveRecord::Base
  belongs_to :observation, :inverse_of => :observation_field_values
  belongs_to :observation_field
  belongs_to :user
  belongs_to :updater, :class_name => 'User'
  has_one :annotation, dependent: :destroy
  
  before_validation :strip_value
  before_save :set_user
  after_create :create_annotation
  validates_uniqueness_of :observation_field_id, :scope => :observation_id
  # I'd like to keep this, but since mobile clients could be submitting
  # observations that weren't created on a mobile device now, the check really
  # needs to happen in the controller... but not sure how best to do that
  # validates_presence_of :value, :if => lambda {|ofv| ofv.observation && !ofv.observation.mobile? }
  validates_presence_of :observation_field_id
  validates_presence_of :observation
  validates_length_of :value, :maximum => 2048
  # validate :validate_observation_field_datatype, :if => lambda {|ofv| ofv.observation }
  # Again, we can't support this until all mobile clients support all field types
  validate :validate_observation_field_allowed_values

  after_save :update_observation_field_counts

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
    where("observations.quality_grade = ?", quality_grade)
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
    else
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

  def update_observation_field_counts
    observation_field.update_counts
  end

  def create_annotation
    return unless observation
    return unless observation_field.datatype == "text"
    stripped_value = value.strip.downcase
    return unless ControlledTerm::VALUES_TO_MIGRATE[stripped_value.to_sym]
    controlled_value = ControlledTerm.first_term_by_label(stripped_value)
    return unless controlled_value
    controlled_attribute = ControlledTerm.first_term_by_label(
      ControlledTerm::VALUES_TO_MIGRATE[stripped_value.to_sym].to_s)
    return unless controlled_attribute
    Annotation.create(observation_field_value: self, resource: observation,
      controlled_attribute: controlled_attribute,
      controlled_value: controlled_value,
      user_id: user_id,
      created_at: created_at)
  end

  def as_indexed_json(options={})
    {
      uuid: uuid,
      name: observation_field.name,
      value: self.value
    }
  end

end
