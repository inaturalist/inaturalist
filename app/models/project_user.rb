class ProjectUser < ActiveRecord::Base
  
  belongs_to :project
  belongs_to :user
  before_destroy :prevent_owner_from_leaving
  validates_uniqueness_of :user_id, :scope => :project_id, :message => "already a member of this project"
  validates_rules_from :project, :rule_methods => [:has_time_zone?]
  
  named_scope :curators, :conditions => {:role => "curator"}
  
  def prevent_owner_from_leaving
    raise "The owner of a project can't leave the project" if project.user_id == user_id
  end
  
  def has_time_zone?
    user.time_zone?
  end
  
  def is_curator?
    role == 'curator'
  end
  
  def update_observations_counter_cache
    thecount = ProjectObservation.count(
      :include => {:observation => :taxon},
      :conditions => [
        "project_id = ? AND observations.user_id = ? AND taxa.rank_level <= ?", 
        project_id, user_id, Taxon::RANK_LEVELS['species']
      ]
    )
    update_attributes(:observations_count => thecount)
  end
  
  def update_taxa_counter_cache
    thecount = ProjectObservation.count(
      :select => "distinct observations.taxon_id",
      :include => {:observation => :taxon},
      :conditions => [
        "project_id = ? AND observations.user_id = ? AND taxa.rank_level <= ?", 
        project_id, user_id, Taxon::RANK_LEVELS['species']
      ]
    )
    update_attributes(:taxa_count => thecount)
  end
  
  def self.update_observations_counter_cache_from_project_and_user(project_id, user_id)
    return unless project_user = ProjectUser.first(:conditions => {
      :project_id => project_id, 
      :user_id => user_id
    })
    project_user.update_observations_counter_cache
  end
  
  def self.update_taxa_counter_cache_from_project_and_user(project_id, user_id)
    return unless project_user = ProjectUser.first(:conditions => {
      :project_id => project_id, 
      :user_id => user_id
    })
    project_user.update_taxa_counter_cache
  end
  
end
