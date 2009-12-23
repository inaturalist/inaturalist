class ObservationPhoto < ActiveRecord::Base
  belongs_to :observation
  belongs_to :photo
end