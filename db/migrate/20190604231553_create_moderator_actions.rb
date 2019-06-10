class CreateModeratorActions < ActiveRecord::Migration
  def change
    create_table :moderator_actions do |t|
      t.string :resource_type
      t.integer :resource_id
      t.integer :user_id
      t.string :action
      t.string :reason
      t.timestamps
    end
    add_index :moderator_actions, [:resource_type, :resource_id]
    add_index :moderator_actions, :user_id
  end
end
