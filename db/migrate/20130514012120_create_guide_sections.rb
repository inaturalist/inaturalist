class CreateGuideSections < ActiveRecord::Migration
  def change
    create_table :guide_sections do |t|
      t.integer :guide_taxon_id
      t.string :title
      t.text :description

      t.timestamps
    end
    add_index :guide_sections, :guide_taxon_id
  end
end
