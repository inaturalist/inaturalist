# frozen_string_literal: true

class AddApiEndpointCompletedAtIndexToApiEndpointCaches < ActiveRecord::Migration[6.1]
  def change
    add_index :api_endpoint_caches, [:api_endpoint_id, :request_completed_at],
      name: "index_api_endpoint_caches_on_api_endpoint_id_and_completed_at"
  end
end
