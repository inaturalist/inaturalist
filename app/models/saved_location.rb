class SavedLocation < ActiveRecord::Base
  belongs_to :user, inverse_of: :saved_locations
  validates :title, :latitude, :longitude, :user, presence: true
  validates :title, uniqueness: { scope: :user_id }

  def serializable_hash( opts = nil )
    options = opts ? opts.clone : { }
    super( opts ).merge(
      latitude: latitude.to_f,
      longitude: longitude.to_f
    )
  end
end
