class CreateObservationLinks < ActiveRecord::Migration
  def self.up
    create_table :observation_links do |t|
      t.integer :observation_id
      t.string :rel
      t.string :href
      t.string :href_name

      t.timestamps
    end
    
    add_index :observation_links, [:observation_id, :href]
  end

  def self.down
    drop_table :observation_links
  end
end
