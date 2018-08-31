class SavedLocation < ActiveRecord::Base
  belongs_to :user, inverse_of: :saved_locations
  validates :title, :latitude, :longitude, :user, presence: true
  validates :title, uniqueness: { scope: :user_id }
end
