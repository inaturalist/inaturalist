class AddSomeIndices < ActiveRecord::Migration
  def change
    add_index :updates, :created_at
    add_index :observations, :created_at
    add_index :observations, :observed_on
    add_index :identifications, :created_at
  end
end
