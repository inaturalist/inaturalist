class ChangePositionalAccuracyToRadiusForTrips < ActiveRecord::Migration
  def up
    rename_column :posts, :positional_accuracy, :radius
  end

  def down
    rename_column :posts, :radius, :positional_accuracy
  end
end
