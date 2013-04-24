class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.integer :user_id
      t.integer :from_user_id
      t.integer :to_user_id
      t.integer :thread_id
      t.string :subject
      t.text :body
      t.datetime :read_at

      t.timestamps
    end

    add_index :messages, [:user_id, :from_user_id]
    add_index :messages, [:user_id, :to_user_id, :read_at]
    # add_index :messages, [:user_id, :read_at]
  end
end
