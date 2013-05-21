class GuideSection < ActiveRecord::Base
  attr_accessible :description, :guide_taxon_id, :title
  belongs_to :guide_taxon, :inverse_of => :guide_sections
end
