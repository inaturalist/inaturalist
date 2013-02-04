class AddLastObsIndexToListedTaxa < ActiveRecord::Migration
  def change
    remove_index :listed_taxa, :last_observation_id
    remove_index :listed_taxa, [:list_id, :lft]
    add_index :listed_taxa, [:last_observation_id, :list_id]
  end
end
