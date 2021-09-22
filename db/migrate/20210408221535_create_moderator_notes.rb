class CreateModeratorNotes < ActiveRecord::Migration
  def change
    create_table :moderator_notes do |t|
      t.integer :user_id
      t.text :body
      t.integer :subject_user_id

      t.timestamps null: false
    end
    add_index :moderator_notes, :user_id
    add_index :moderator_notes, :subject_user_id
  end
end
