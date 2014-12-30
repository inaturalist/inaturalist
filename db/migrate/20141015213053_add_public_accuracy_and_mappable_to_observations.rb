class AddPublicAccuracyAndMappableToObservations < ActiveRecord::Migration
  def up
    add_column :observations, :public_positional_accuracy, :integer
    add_column :observations, :mappable, :boolean, default: false
    add_index :observations, :mappable
    say "Run rake inaturalist:update_public_accuracy to update your data"
  end

  def down
    remove_index :observations, :mappable
    remove_column :observations, :mappable
    remove_column :observations, :public_positional_accuracy
  end
end
