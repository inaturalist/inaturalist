class RemoveShowFromPlaceFromProject < ActiveRecord::Migration
  def change
    remove_column :projects, :show_from_place, :boolean
  end
end
