class ExplodedAtlasPlace < ApplicationRecord
  belongs_to :atlas
  belongs_to :place
  validates_uniqueness_of :atlas_id, scope: :place_id
end
