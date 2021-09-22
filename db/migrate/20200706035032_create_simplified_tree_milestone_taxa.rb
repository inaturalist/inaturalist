class CreateSimplifiedTreeMilestoneTaxa < ActiveRecord::Migration
  def change
    create_table :simplified_tree_milestone_taxa do |t|
      t.integer :taxon_id
    end
  end
end
