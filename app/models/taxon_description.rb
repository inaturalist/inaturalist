# frozen_string_literal: true

class TaxonDescription < ApplicationRecord
  # locale can potentially have a region, since the different localized
  # wikipedias support regional "variants"
  belongs_to :taxon
end
