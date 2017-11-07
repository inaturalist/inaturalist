class AddCompleteRankToTaxa < ActiveRecord::Migration
  def change
    add_column :taxa, :complete_rank, :string
  end
end
