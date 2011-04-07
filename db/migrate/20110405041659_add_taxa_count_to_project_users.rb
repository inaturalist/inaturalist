class AddTaxaCountToProjectUsers < ActiveRecord::Migration
  def self.up
    add_column :project_users, :taxa_count, :integer, :default => 0
    ProjectUser.all.each do |project_user|
      project_user.taxa_count = project_user.project.project_observations.count(
        :select => "distinct observations.taxon_id",
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
    remove_column :project_users, :taxa_count
  end
end
