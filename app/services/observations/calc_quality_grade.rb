require "forwardable"

module Observations
  class CalcQualityGrade
    extend Forwardable
    def_delegators :observation,
      :research_grade_candidate?,
      :voted_in_to_needs_id?,
      :community_taxon_id,
      :community_taxon_rejected?,
      :owners_identification,
      :community_taxon,
      :voted_out_of_needs_id?,
      :community_taxon_at_species_or_lower?,
      :community_taxon_below_family?

    def initialize(observation)
      @observation = observation
    end

    def call
      if !research_grade_candidate?
        Observation::CASUAL
      elsif voted_in_to_needs_id?
        Observation::NEEDS_ID
      elsif community_taxon_id && community_taxon_rejected?
        if owners_identification.blank? || owners_identification.maverick?
          Observation::CASUAL
        elsif (
          owners_identification &&
          owners_identification.taxon.rank_level && (
            (
              owners_identification.taxon.rank_level <= Taxon::SPECIES_LEVEL &&
              community_taxon.self_and_ancestor_ids.include?( owners_identification.taxon.id )
            ) || (
              owners_identification.taxon.rank_level == Taxon::GENUS_LEVEL &&
              community_taxon == owners_identification.taxon &&
              voted_out_of_needs_id?
            )
          )
        )
          Observation::RESEARCH_GRADE
        elsif voted_out_of_needs_id?
          Observation::CASUAL
        else
          Observation::NEEDS_ID
        end
      elsif community_taxon_at_species_or_lower?
        Observation::RESEARCH_GRADE
      elsif community_taxon_id && voted_out_of_needs_id?
        if community_taxon_below_family?
          Observation::RESEARCH_GRADE
        else
          Observation::CASUAL
        end
      else
        Observation::NEEDS_ID
      end
    end

    private

    attr_reader :observation
  end
end
