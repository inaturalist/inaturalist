class TripTaxon < ActiveRecord::Base
  belongs_to :trip, :inverse_of => :trip_taxa #, :class_name => "Post"
  belongs_to :taxon
end