class AtlasAlteration < ApplicationRecord
  belongs_to :atlas
  belongs_to :place
  belongs_to :user
end
