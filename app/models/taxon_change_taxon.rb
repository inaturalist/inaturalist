class TaxonChangeTaxon < ActiveRecord::Base
  belongs_to :taxon_change
  belongs_to :taxon

  validates_presence_of :taxon
  validates_presence_of :taxon_change, :unless => :nested
  attr_accessor :nested
  # TODO replace this nested junk with inverse_of relats in Rails 3
end
