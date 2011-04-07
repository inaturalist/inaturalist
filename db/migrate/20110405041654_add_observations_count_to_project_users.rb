class AddObservationsCountToProjectUsers < ActiveRecord::Migration
  def self.up
    add_column :project_users, :observations_count, :integer, :default => 0
    ProjectUser.all.each do |project_user|
      project_user.observations_count = project_user.project.project_observations.count(
        :include => {:observation => :taxon},
        :conditions => [
         "observations.user_id = ? AND taxa.rank_level <= ?", 
         project_user.user_id, Taxon::RANK_LEVELS['species']
        ]
       )
      project_user.save
    end
  end

  def self.down
    remove_column :project_users, :observations_count
  end
end
