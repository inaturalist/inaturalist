class AddCompleteToTaxa < ActiveRecord::Migration
  def change
    add_column :taxa, :complete, :boolean
  end
end
