class AddCountsToObservationFields < ActiveRecord::Migration
  def change
    add_column :observation_fields, :values_count, :integer
    add_column :observation_fields, :users_count, :integer
  end
end
