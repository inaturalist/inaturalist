# frozen_string_literal: true

class CreateExemplarIdentifications < ActiveRecord::Migration[6.1]
  def up
    create_table :exemplar_identifications do | t |
      t.integer :identification_id, null: false
      t.integer :nominated_by_user_id
      t.datetime :nominated_at
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :exemplar_identifications, :identification_id, unique: true
    ExemplarIdentification.__elasticsearch__.create_index! force: true
  end

  def down
    drop_table :exemplar_identifications
    # not deleting the index on down. If you redo this migration
    # the up method with destory and recreate the index
  end
end
