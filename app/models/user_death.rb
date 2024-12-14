# frozen_string_literal: true

class UserDeath < ApplicationRecord
  belongs_to :user
  has_updater

  def interactions_with_user( other_user )
    # es_params[:filters] << { terms: { "user.id" => [user.id] } }
    # es_params[:aggregate] = {
    #   users_helped: { terms: { field: "observation.user_id", size: 40_000 } }
    # }
    num_identifications_given_by_deceased = Identification.
      elastic_search(
        size: 0,
        track_total_hits: true,
        filters: [
          { terms: { "user.id" => [user_id] } },
          { terms: { "observation.user_id" => [other_user.id] } }
        ]
      ).
      response&.
      hits&.total&.value&.to_i
    num_identifications_received_by_deceased = Identification.
      elastic_search(
        size: 0,
        track_total_hits: true,
        filters: [
          { terms: { "user.id" => [other_user.id] } },
          { terms: { "observation.user_id" => [user_id] } }
        ]
      ).
      response&.
      hits&.total&.value&.to_i
    if num_identifications_given_by_deceased.zero? && num_identifications_received_by_deceased.zero?
      return
    end

    {
      num_identifications_given_by_deceased: num_identifications_given_by_deceased,
      num_identifications_received_by_deceased: num_identifications_received_by_deceased
    }
  end
end
