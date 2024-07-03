# frozen_string_literal: true

class CreateCohortLifecycles < ActiveRecord::Migration[6.1]
  def change
    create_table :cohort_lifecycles do | t |
      t.date :cohort, default: nil
      t.references :user, null: false
      t.string :day0, default: nil
      t.string :day1, default: nil
      t.string :day2, default: nil
      t.string :day3, default: nil
      t.string :day4, default: nil
      t.string :day5, default: nil
      t.string :day6, default: nil
      t.string :day7, default: nil
      t.boolean :retention, default: nil
      t.string :observer_appeal_intervention_group, default: nil
      t.string :first_observation_intervention_group, default: nil
      t.string :error_intervention_group, default: nil
      t.string :captive_intervention_group, default: nil
      t.string :needs_id_intervention_group, default: nil

      t.timestamps
    end
    add_index :cohort_lifecycles, [:cohort, :user_id], unique: true
  end
end
