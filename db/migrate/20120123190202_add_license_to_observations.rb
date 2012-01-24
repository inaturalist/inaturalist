class AddLicenseToObservations < ActiveRecord::Migration
  def self.up
    add_column :observations, :license, :string
  end

  def self.down
    remove_column :observations, :license
  end
end
