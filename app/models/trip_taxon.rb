class TripTaxon < ActiveRecord::Base
  belongs_to :trip, :inverse_of => :trip_taxa #, :class_name => "Post"
  belongs_to :taxon
  validates_uniqueness_of :taxon_id, :scope => :trip_id
  validates_presence_of :taxon
end
