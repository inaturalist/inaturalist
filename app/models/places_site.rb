class PlacesSite < ApplicationRecord
  EXPORTS = "exports"
  belongs_to :place
  belongs_to :site
  validates :scope, inclusion: { in: [PlacesSite::EXPORTS] }
end
