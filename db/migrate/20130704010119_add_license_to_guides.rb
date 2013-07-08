class AddLicenseToGuides < ActiveRecord::Migration
  def change
    add_column :guides, :license, :string, :default => "CC-BY-SA"
  end
end
