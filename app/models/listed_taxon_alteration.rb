class ListedTaxonAlteration < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :place
  belongs_to :user
end
