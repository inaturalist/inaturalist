class ObservationReview < ActiveRecord::Base

  belongs_to :observation
  belongs_to :user

  def self.merge_future_duplicates( reject, keeper )
    unless reject.is_a?( User ) || reject.is_a?( Observation )
      raise "ObservationReview.merge_future_duplicates only works for observations right now"
    end
    reject.observation_reviews.delete_all
  end

end
