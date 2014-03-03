class AddCompleteToTripPurposes < ActiveRecord::Migration
  def change
    add_column :trip_purposes, :complete, :boolean, :default => false
  end
end
