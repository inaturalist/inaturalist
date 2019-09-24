require "forwardable"

module Observations
  class UpdateStats
    extend Forwardable
    def_delegators :observation,
      :id,
      :identifications,
      :identifications_count,
      :taxon_id,
      :user_id,
      :community_taxon_nodes,
      :get_quality_grade,
      :num_identification_agreements_changed?,
      :num_identification_disagreements_changed?,
      :quality_grade_changed?,
      :identifications_count_changed?,
      :refresh_check_lists,
      :refresh_lists

    def initialize(observation, options = {})
      @observation = observation
      @options = options
    end

    def call
      idents = [identifications.to_a, options[:include]].flatten.compact.uniq
      current_idents = idents.select(&:current?)
      if taxon_id.blank?
        num_agreements    = 0
        num_disagreements = 0
      else
        nodes = community_taxon_nodes
        if node = nodes.detect{|n| n[:taxon].try(:id) == taxon_id}
          num_agreements = node[:cumulative_count]
          num_disagreements = node[:disagreement_count] + node[:conservative_disagreement_count]
          num_agreements -= 1 if current_idents.detect{|i| i.taxon_id == taxon_id && i.user_id == user_id}
          num_agreements = 0 if current_idents.count <= 1
          num_disagreements = 0 if current_idents.count <= 1
        else
          num_agreements    = current_idents.select do |ident| 
            ident.is_agreement?(observation: observation)
          end.size
          num_disagreements = current_idents.select do |ident| 
            ident.is_disagreement?(observation: observation)
          end.size
        end
      end

      # Kinda lame, but Observation#get_quality_grade relies on these numbers
      observation.num_identification_agreements = num_agreements
      observation.num_identification_disagreements = num_disagreements
      observation.identifications_count = idents.size
      new_quality_grade = get_quality_grade
      observation.quality_grade = new_quality_grade

      if !options[:skip_save] && (
          num_identification_agreements_changed? ||
          num_identification_disagreements_changed? ||
          quality_grade_changed? ||
          identifications_count_changed?)
        Observation.where(id: id).update_all(
          num_identification_agreements: num_agreements,
          num_identification_disagreements: num_disagreements,
          quality_grade: new_quality_grade,
          identifications_count: identifications_count)
        refresh_check_lists
        refresh_lists
      end
    end

    private

    attr_reader :observation, :options
  end
end
