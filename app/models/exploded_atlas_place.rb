class ExplodedAtlasPlace < ActiveRecord::Base
  belongs_to :atlas
  belongs_to :place
end
