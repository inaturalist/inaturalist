class GuideRange < ActiveRecord::Base
  attr_accessible :guide_taxon_id, :thumb_url, :medium_url, :original_url
  belongs_to :guide_taxon, :inverse_of => :guide_ranges
end
