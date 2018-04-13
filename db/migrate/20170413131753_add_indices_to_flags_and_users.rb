class AddIndicesToFlagsAndUsers < ActiveRecord::Migration
  def change
    add_index :flags, [ :flaggable_id, :flaggable_type ]
    add_index :users, :updated_at
  end
end
