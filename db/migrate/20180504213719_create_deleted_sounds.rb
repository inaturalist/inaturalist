class CreateDeletedSounds < ActiveRecord::Migration
  def change
    create_table :deleted_sounds do |t|
      t.integer :user_id
      t.integer :sound_id
      t.boolean :removed_from_s3, default: false
      t.boolean :orphan, default: false
      t.timestamps
    end
    add_index :deleted_sounds, :created_at
  end
end
