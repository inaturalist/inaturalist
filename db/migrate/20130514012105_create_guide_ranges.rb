class CreateGuideRanges < ActiveRecord::Migration
  def change
    create_table :guide_ranges do |t|
      t.integer :guide_taxon_id
      t.string :medium_url
      t.string :thumb_url
      t.string :original_url
      t.timestamps
    end
    add_index :guide_ranges, :guide_taxon_id
  end
end
