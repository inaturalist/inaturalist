class AddTimestampsToTripModels < ActiveRecord::Migration
  def change
    add_column :trip_taxa, :created_at, :datetime
    add_column :trip_taxa, :updated_at, :datetime
    add_column :trip_purposes, :created_at, :datetime
    add_column :trip_purposes, :updated_at, :datetime
  end
end
