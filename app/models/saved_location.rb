class SavedLocation < ApplicationRecord
  belongs_to :user, inverse_of: :saved_locations
  validates :title, :latitude, :longitude, :user, presence: true
  validates :title, uniqueness: { scope: :user_id }
  validates_numericality_of :latitude,
    less_than_or_equal_to: 90, 
    greater_than_or_equal_to: -90
  validates_numericality_of :longitude,
    less_than_or_equal_to: 180, 
    greater_than_or_equal_to: -180

  def serializable_hash( opts = nil )
    options = opts ? opts.clone : { }
    super( opts ).merge(
      latitude: latitude.to_f,
      longitude: longitude.to_f
    )
  end
end
