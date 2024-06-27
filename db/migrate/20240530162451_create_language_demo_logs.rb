# frozen_string_literal: true

class CreateLanguageDemoLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :language_demo_logs do | t |
      t.integer :user_id
      t.string :search_term
      t.integer :taxon_id
      t.integer :page
      t.json :votes
      t.timestamps
    end
  end
end
