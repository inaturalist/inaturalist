class AddGeoprivacyToObservations < ActiveRecord::Migration
  def self.up
    add_column :observations, :geoprivacy, :string
  end

  def self.down
    remove_column :observations, :geoprivacy
  end
end
