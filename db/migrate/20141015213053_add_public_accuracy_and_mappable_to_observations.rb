class AddPublicAccuracyAndMappableToObservations < ActiveRecord::Migration
  def up
    add_column :observations, :public_positional_accuracy, :integer
    add_column :observations, :mappable, :boolean, default: false
    add_index :observations, :mappable
    Rake::Task['inaturalist:update_public_accuracy'].invoke
  end

  def down
    remove_index :observations, :mappable
    remove_column :observations, :mappable
    remove_column :observations, :public_positional_accuracy
  end
end
