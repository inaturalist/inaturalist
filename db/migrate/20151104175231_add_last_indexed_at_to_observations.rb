class AddLastIndexedAtToObservations < ActiveRecord::Migration
  def up
    add_column :observations, :last_indexed_at, :datetime
    add_index :observations, :last_indexed_at
  end

  def down
    remove_column :observations, :last_indexed_at
  end
end
