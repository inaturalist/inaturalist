class AddUpdaterIdToConservationStatuses < ActiveRecord::Migration
  def up
    add_column :conservation_statuses, :updater_id, :integer
    add_index :conservation_statuses, :updater_id
    execute "UPDATE conservation_statuses SET updater_id = user_id"
  end

  def down
    remove_column :conservation_statuses, :updater_id
  end
end
