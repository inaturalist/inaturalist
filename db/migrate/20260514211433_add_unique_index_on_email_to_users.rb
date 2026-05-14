# frozen_string_literal: true

class AddUniqueIndexOnEmailToUsers < ActiveRecord::Migration[6.1]
  def up
    # remove the existing non-unique index so a unique index can be added
    remove_index :users, :email
    add_index :users, :email, unique: true
  end

  def down
    remove_index :users, :email
    # recreating the index without the uniqueness contraint
    add_index :users, :email
  end
end
