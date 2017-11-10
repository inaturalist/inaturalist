class TaxonCurator < ActiveRecord::Base
  belongs_to :taxon
  belongs_to :user

  validate :taxon_is_complete
  validate :user_is_a_site_curator

  def to_s
    "<TaxonCurator #{id} user_id: #{user_id} taxon_id: #{taxon_id}>"
  end

  def taxon_is_complete
    return true if taxon.complete?
    complete_ancestor = taxon.complete_taxon
    if !complete_ancestor || Taxon::RANK_LEVELS[complete_ancestor.try(:complete_rank)].to_i > taxon.rank_level.to_i
      errors.add( :taxon_id, "must be complete or a complete descendant" )
    end
  end

  def user_is_a_site_curator
    if user && !user.is_curator?
      errors.add( :user_id, "must be a site curator" )
    end
    true
  end
end
