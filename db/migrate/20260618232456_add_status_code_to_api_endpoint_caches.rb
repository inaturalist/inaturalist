# frozen_string_literal: true

class AddStatusCodeToApiEndpointCaches < ActiveRecord::Migration[6.1]
  def change
    add_column :api_endpoint_caches, :status_code, :integer
  end
end
