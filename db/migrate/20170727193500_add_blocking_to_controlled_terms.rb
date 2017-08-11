class AddBlockingToControlledTerms < ActiveRecord::Migration
  def change
    add_column :controlled_terms, :blocking, :boolean, default: false
  end
end
