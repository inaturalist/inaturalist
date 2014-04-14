class AddSourceColsToGuideContent < ActiveRecord::Migration
  def change
    add_column :guide_sections, :license, :string
    add_column :guide_sections, :source_url, :string
    add_column :guide_sections, :rights_holder, :string
    add_column :guide_sections, :source_id, :integer
    add_index :guide_sections, :source_id

    add_column :guide_ranges, :license, :string
    add_column :guide_ranges, :source_url, :string
    add_column :guide_ranges, :rights_holder, :string
    add_column :guide_ranges, :source_id, :integer
    add_index :guide_ranges, :source_id
  end
end
