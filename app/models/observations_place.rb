class ObservationsPlace < ActiveRecord::Base

  belongs_to :observation
  belongs_to :place

  def self.merge_future_duplicates( reject, keeper )
    if reject.is_a?( Place )
      ObservationsPlace.where( place_id: reject.id ).delete_all
    elsif reject.is_a?( Observation )
      ObservationsPlace.where( observation_id: reject.id ).delete_all
    end
  end

end
