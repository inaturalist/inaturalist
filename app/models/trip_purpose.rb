class TripPurpose < ActiveRecord::Base
  belongs_to :trip
  belongs_to :resource, :polymorphic => true
end
