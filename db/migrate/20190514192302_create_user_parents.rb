class CreateUserParents < ActiveRecord::Migration
  def change
    create_table :user_parents do |t|
      t.integer :user_id
      t.integer :parent_user_id
      t.string :name
      t.string :email
      t.string :child_name

      t.timestamps null: false
    end
    add_index :user_parents, :user_id
    add_index :user_parents, :parent_user_id
    add_index :user_parents, :email
  end
end
