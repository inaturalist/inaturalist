class CreateObservationFields < ActiveRecord::Migration
  def self.up
    create_table :observation_fields do |t|
      t.string :name
      t.string :datatype
      t.integer :user_id
      t.string :description

      t.timestamps
    end
    add_index :observation_fields, :name
  end

  def self.down
    drop_table :observation_fields
  end
end
