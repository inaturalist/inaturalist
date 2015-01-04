class AddUserColumnsToGuideSections < ActiveRecord::Migration
  def up
    add_column :guide_sections, :creator_id, :integer
    add_column :guide_sections, :updater_id, :integer
    add_index :guide_sections, :creator_id
    add_index :guide_sections, :updater_id
    execute <<-SQL
      UPDATE guide_sections 
      SET creator_id = guides.user_id, updater_id = guides.user_id
      FROM guides, guide_taxa 
      WHERE 
        guides.id = guide_taxa.guide_id
        AND guide_taxa.id = guide_sections.guide_taxon_id
    SQL
  end
  def down
    remove_column :guide_sections, :creator_id
    remove_column :guide_sections, :updater_id
  end
end
