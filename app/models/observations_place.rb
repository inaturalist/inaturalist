class ObservationsPlace < ActiveRecord::Base

  belongs_to :observation
  belongs_to :place

end
