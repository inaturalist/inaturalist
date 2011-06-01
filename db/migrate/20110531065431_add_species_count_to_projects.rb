class AddSpeciesCountToProjects < ActiveRecord::Migration
  def self.up
    remove_column :lists, :species_count
    add_column :projects, :species_count, :integer, :default => 0
    
    Project.find_each do |project|
      Project.update_species_count(project.id)
    end
    
    ProjectUser.find_each do |project_user|
      project_user.update_taxa_counter_cache
      project_user.update_observations_counter_cache
    end
  end

  def self.down
    remove_column :projects, :species_count
    add_column :lists, :species_count, :integer, :default => 0
    ProjectList.find_each do |the_list|
      the_list.species_count = the_list.listed_taxa.count(
        'DISTINCT(taxon.id)',
        :include =>:taxon,
        :conditions => [
          "taxa.rank_level <= ?",
          Taxon::RANK_LEVELS['species']
        ]
      )
      the_list.save
    end
  end
end
