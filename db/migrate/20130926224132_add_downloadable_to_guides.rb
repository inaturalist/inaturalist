class AddDownloadableToGuides < ActiveRecord::Migration
  def change
    add_column :guides, :downloadable, :boolean, :default => false
  end
end
