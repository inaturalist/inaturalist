# frozen_string_literal: true

class CreateExemplarIdentifications < ActiveRecord::Migration[6.1]
  def change
    create_table :exemplar_identifications do | t |
      t.integer :identification_id, null: false
      t.integer :nominated_by_user_id
      t.datetime :nominated_at
      t.timestamps
    end

    add_index :exemplar_identifications, :identification_id, unique: true
  end
end
