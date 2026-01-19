# frozen_string_literal: true

class CreateCohortStatistics < ActiveRecord::Migration[6.1]
  def change
    create_table :cohort_statistics do | t |
      t.string :stat_type
      t.datetime :created_at
      t.json :data
    end

    add_index :cohort_statistics, [:stat_type, :created_at]
  end
end
