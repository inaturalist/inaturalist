class ObservationFieldValue < ActiveRecord::Base
  belongs_to :observation
  belongs_to :observation_field
  
  validates_uniqueness_of :observation_field_id, :scope => :observation_id
  validates_presence_of :value
  validates_presence_of :observation_field_id
  
  before_validation :strip_value
  validate :validate_observation_field_datatype
  validate :validate_observation_field_allowed_values
  
  LAT_LON_REGEX = /#{Observation::COORDINATE_REGEX},#{Observation::COORDINATE_REGEX}/
  
  def strip_value
    self.value = value.strip unless value.nil?
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
    end
  end
  
  def validate_observation_field_allowed_values
    return true if observation_field.allowed_values.blank?
    allowed_values = observation_field.allowed_values.split('|')
    unless allowed_values.include?(value)
      errors.add(:value, "must be #{allowed_values[0..-2].map{|v| "#{v}, "}}or #{allowed_values.last}")
    end
  end
end
