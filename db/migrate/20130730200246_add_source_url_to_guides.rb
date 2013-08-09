class AddSourceUrlToGuides < ActiveRecord::Migration
  def change
    add_column :guides, :source_url, :string
    add_index :guides, :source_url
  end
end
