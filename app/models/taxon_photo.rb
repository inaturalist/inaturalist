class TaxonPhoto < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :photo
end
