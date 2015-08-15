class ObservationReview < ActiveRecord::Base

  belongs_to :observation
  belongs_to :user

end
