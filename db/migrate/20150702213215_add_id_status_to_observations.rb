class AddIdStatusToObservations < ActiveRecord::Migration
  def change
    add_column :observations, :id_status, :string
    add_index :observations, :id_status
  end
end
