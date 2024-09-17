# frozen_string_literal: true

class TaxonDescription < ApplicationRecord
  # locale can potential have a region, since the different localized
  # wikipedias do support regional "variants"
  belongs_to :taxon
end
