class CreateObservationFieldValues < ActiveRecord::Migration
  def self.up
    create_table :observation_field_values do |t|
      t.integer :observation_id
      t.integer :observation_field_id
      t.string :value

      t.timestamps
    end
    add_index :observation_field_values, :observation_id
    add_index :observation_field_values, :observation_field_id
  end

  def self.down
    drop_table :observation_field_values
  end
end
