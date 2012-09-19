class AddPositionToProjectObservationFields < ActiveRecord::Migration
  def change
    add_column :project_observation_fields, :position, :integer
    add_index :project_observation_fields, [:project_id, :position], :name => :pof_projid_pos
  end
end
