class CreateProjectObservationFields < ActiveRecord::Migration
  def change
    create_table :project_observation_fields do |t|
      t.integer :project_id
      t.integer :observation_field_id
      t.boolean :required
      t.timestamps
    end
    add_index :project_observation_fields, [:project_id, :observation_field_id], :name => :pof_projid_ofid
  end
end
