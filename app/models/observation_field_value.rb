class ObservationFieldValue < ActiveRecord::Base
  belongs_to :observation
  belongs_to :observation_field
  
  validates_uniqueness_of :observation_field_id, :scope => :observation_id
  validates_presence_of :value
  validates_presence_of :observation_field_id
  # validates_presence_of :observation_id
  validate :validate_observation_field_datatype
  
  def validate_observation_field_datatype
    case observation_field.datatype
    when "numeric"
      errors.add(:value, "must be a number") if value !~ Observation::FLOAT_REGEX
    when "date"
    end
  end
end
