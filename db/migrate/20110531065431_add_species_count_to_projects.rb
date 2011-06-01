class AddSpeciesCountToProjects < ActiveRecord::Migration
  def self.up
    remove_column :lists, :species_count
    add_column :projects, :species_count, :integer, :default => 0
    Project.all.each do |the_project|
      project_id = the_project.id
      user_taxon_ids = ProjectObservation.all(
        :select => "distinct observations.taxon_id",
        :include => [{:observation => :taxon}, :curator_identification],
        :conditions => [
          "identifications.id IS NULL AND project_id = ? AND taxa.rank_level <= ?",
          project_id, Taxon::RANK_LEVELS['species']
        ]
      ).map{|po| po.observation.taxon_id}
      
      curator_taxon_ids = ProjectObservation.all(
        :select => "distinct identifications.taxon_id",
        :include => [:observation, {:curator_identification => :taxon}],
        :conditions => [
          "identifications.id IS NOT NULL AND project_id = ? AND taxa.rank_level <= ?",
          project_id, Taxon::RANK_LEVELS['species']
        ]
      ).map{|po| po.curator_identification.taxon_id}

      the_project.species_count = (user_taxon_ids + curator_taxon_ids).uniq.size
      the_project.save
    end
    
    ProjectUser.all.each do |project_user|
      user_taxon_ids = ProjectObservation.all(
        :select => "distinct observations.taxon_id",
        :include => [{:observation => :taxon}, :curator_identification],
        :conditions => [
          "identifications.id IS NULL AND project_id = ? AND observations.user_id = ? AND taxa.rank_level <= ?",
          project_user.project_id, project_user.user_id, Taxon::RANK_LEVELS['species']
        ]
      ).map{|po| po.observation.taxon_id}

      curator_taxon_ids = ProjectObservation.all(
        :select => "distinct identifications.taxon_id",
        :include => [:observation, {:curator_identification => :taxon}],
        :conditions => [
          "identifications.id IS NOT NULL AND project_id = ? AND observations.user_id = ? AND taxa.rank_level <= ?",
          project_user.project_id, project_user.user_id, Taxon::RANK_LEVELS['species']
        ]
      ).map{|po| po.curator_identification.taxon_id}

      project_user.taxa_count = (user_taxon_ids + curator_taxon_ids).uniq.size
      
      user_count = ProjectObservation.count(
        :include => [{:observation => :taxon}, :curator_identification],
        :conditions => [
          "identifications.id IS NULL AND project_id = ? AND observations.user_id = ? AND taxa.rank_level <= ?",
          project_user.project_id, project_user.user_id, Taxon::RANK_LEVELS['species']
        ]
      )

      curator_count = ProjectObservation.count(
        :include => [:observation, {:curator_identification => :taxon}],
        :conditions => [
          "identifications.id IS NOT NULL AND project_id = ? AND observations.user_id = ? AND taxa.rank_level <= ?",
          project_user.project_id, project_user.user_id, Taxon::RANK_LEVELS['species']
        ]
      )
      
      project_user.observations_count = (user_count + curator_count)
      project_user.save
    end
  end

  def self.down
    remove_column :projects, :species_count
    add_column :lists, :species_count, :integer, :default => 0
    List.all.each do |the_list|
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
