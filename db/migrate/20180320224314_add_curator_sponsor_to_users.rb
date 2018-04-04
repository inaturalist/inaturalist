class AddCuratorSponsorToUsers < ActiveRecord::Migration
  def change
    add_column :users, :curator_sponsor_id, :integer
    add_index :users, :curator_sponsor_id
  end
end
