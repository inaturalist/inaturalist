class TaxonCurator < ActiveRecord::Base
  belongs_to :concept
  belongs_to :user

  validate :concept_is_framework
  validate :user_is_a_site_curator

  def to_s
    "<TaxonCurator #{id} user_id: #{user_id} taxon_id: #{taxon_id}>"
  end

  def concept_is_framework
    return true if concept.framework?
    errors.add( :concept_id, "must be a concept framework" )
  end

  def user_is_a_site_curator
    if user && !user.is_curator?
      errors.add( :user_id, "must be a site curator" )
    end
    true
  end
end
