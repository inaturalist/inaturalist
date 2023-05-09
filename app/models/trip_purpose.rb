class TripPurpose < ApplicationRecord
  belongs_to :trip
  belongs_to :resource, :polymorphic => true
end
