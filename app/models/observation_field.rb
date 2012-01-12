class ObservationField < ActiveRecord::Base
  belongs_to :user
  has_many :observation_field_values, :dependent => :destroy
  has_many :observations, :through => :observation_field_values
  
  validates_uniqueness_of :name
  validates_presence_of :name
  
  TYPES = %w(text numeric date time datetime location)
end
