class TaxonCurator < ApplicationRecord
  belongs_to :taxon # deprecated, remove when we're sure transition to taxon frameworks is complete
  belongs_to :taxon_framework
  belongs_to :user

  validate :taxon_framework_covers
  validate :user_is_a_site_curator

  def to_s
    "<TaxonCurator #{ id } user_id: #{ user_id } taxon__framework_id: #{ taxon_framework_id }>"
  end

  def taxon_framework_covers
    return true if taxon_framework.covers?
    errors.add( :taxon_framework_id, "must be a taxon framework with coverage" )
  end

  def user_is_a_site_curator
    if user && !user.is_curator?
      errors.add( :user_id, "must be a site curator" )
    end
    true
  end
end
