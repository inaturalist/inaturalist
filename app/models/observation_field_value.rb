class ObservationFieldValue < ActiveRecord::Base
  belongs_to :observation, :inverse_of => :observation_field_values
  belongs_to :observation_field
  
  before_validation :strip_value
  validates_uniqueness_of :observation_field_id, :scope => :observation_id
  validates_presence_of :value
  validates_presence_of :observation_field_id
  validates_length_of :value, :maximum => 2048
  validate :validate_observation_field_datatype
  validate :validate_observation_field_allowed_values

  after_create  :touch_observation
  after_destroy :touch_observation
  
  LAT_LON_REGEX = /#{Observation::COORDINATE_REGEX},#{Observation::COORDINATE_REGEX}/

  scope :datatype, lambda {|datatype| includes(:observation_field).where("observation_fields.datatype = ?", datatype)}
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
    scope = includes(:observation).scoped
    if license == 'none'
      scope.where("observations.license IS NULL")
    elsif Observation::LICENSE_CODES.include?(license)
      scope.where("observations.license = ?", license)
    else
      scope.where("observations.license IS NOT NULL")
    end
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
  
  def validate_observation_field_datatype
    case observation_field.datatype
    when "numeric"
      errors.add(:value, "must be a number") if value !~ Observation::FLOAT_REGEX
    when "location"
      errors.add(:value, "must decimal latitude and decimal longitude separated by a comma") if value !~ LAT_LON_REGEX
    when "date"
      errors.add(:value, "must by in the form YYYY-MM-DD") unless value =~ /^\d{4}\-\d{2}\-\d{2}$/
    when "datetime"
      begin
        Time.iso8601(value)
      rescue ArgumentError => e
        errors.add(:value, "must by in the form #{Time.now.iso8601}")
      end
    when "time"
      begin
        Time.parse(value)
        if value !~ /^\d\d:\d\d/
          errors.add(:value, "must by in the form hh:mm")
        end
      rescue ArgumentError => e
        errors.add(:value, "must by in the form hh:mm")
      end
    when "dna"
      if value =~ /[^ATCG\s]/
        errors.add(:value, :dna_only_atcg)
      end
    end
  end
  
  def validate_observation_field_allowed_values
    return true if observation_field.allowed_values.blank?
    values = observation_field.allowed_values.split('|')
    unless values.include?(value)
      errors.add(:value, 
        "of #{observation_field.name} must be #{values[0..-2].map{|v| "#{v}, "}.join}or #{values.last}.")
    end
  end

  def touch_observation
    observation.touch if observation
    true
  end

end
