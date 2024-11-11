# frozen_string_literal: true

class AddAnnotatedObservationsCountToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :annotated_observations_count, :integer, default: 0
  end
end
