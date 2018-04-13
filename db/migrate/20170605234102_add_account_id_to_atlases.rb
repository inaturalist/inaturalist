class AddAccountIdToAtlases < ActiveRecord::Migration
  def change
    add_column :atlases, :account_id, :integer
  end
end
