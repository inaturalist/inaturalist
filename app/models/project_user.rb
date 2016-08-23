class ProjectUser < ActiveRecord::Base
  
  belongs_to :project
  belongs_to :user, touch: true
  auto_subscribes :user, :to => :project
  
  after_save :check_role,
             :remove_updates,
             :subscribe_to_assessment_sections_later,
             :index_project,
             :update_project_observations_later
  after_destroy :remove_updates, :index_project
  validates_uniqueness_of :user_id, :scope => :project_id, :message => "already a member of this project"
  validates_presence_of :project, :user
  validates_rules_from :project, :rule_methods => [:has_time_zone?]
  validate :user_invited?

  # curator_coordinate_access on ProjectUser controls the default value for
  # curator_coordinate_access on ProjectObservation
  CURATOR_COORDINATE_ACCESS_OBSERVER = "observer" # curators can only access coordinates for observations added by the observer
  CURATOR_COORDINATE_ACCESS_ANY = "any" # curators can access coordinates for observations added by anyone
  CURATOR_COORDINATE_ACCESS_NONE = "none" # curators cannot access coordinates
  CURATOR_COORDINATE_ACCESS_OPTIONS = [
    CURATOR_COORDINATE_ACCESS_OBSERVER,
    CURATOR_COORDINATE_ACCESS_ANY,
    CURATOR_COORDINATE_ACCESS_NONE
  ]
  preference :curator_coordinate_access, :string, :default => CURATOR_COORDINATE_ACCESS_OBSERVER
  preference :updates, :boolean, :default => true
  
  CURATOR_CHANGE_NOTIFICATION = "curator_change"
  ROLES = %w(curator manager)
  ROLES.each do |role|
    const_set role.upcase, role
    scope role.pluralize, -> { where(:role => role) }
  end

  notifies_subscribers_of :project, :on => :save, :notification => CURATOR_CHANGE_NOTIFICATION, 
    :include_notifier => true,
    # don't bother queuing this if there's no relevant role change
    :queue_if => Proc.new {|pu|
      pu.role_changed? && (ROLES.include?(pu.role) || pu.user_id == pu.project.user_id)
    },
    # check to make sure role status hasn't changed since queuing
    :if => Proc.new {|pu| ROLES.include?(pu.role) || pu.user_id == pu.project.user_id}

  def to_s
    "<ProjectUser #{id} project: #{project_id} user: #{user_id} role: #{role}>"
  end

  def project_observations
    project.project_observations.joins(:observation).where(observations: { user_id: user_id })
  end

  def remove_updates
    return true unless role_changed? && role.blank?
    UpdateAction.delete_and_purge(
      notifier_type: "ProjectUser",
      notifier_id: id,
      resource_type: "Project",
      resource_id: project_id)
    true
  end

  def subscribe_to_assessment_sections_later
    return true unless role_changed? && !role.blank?
    delay(:priority => USER_INTEGRITY_PRIORITY).subscribe_to_assessment_sections
    true
  end

  def update_project_observations_later
    return true unless preferred_curator_coordinate_access_changed?
    delay( priority: USER_INTEGRITY_PRIORITY ).update_project_observations_curator_coordinate_access
    true
  end

  def update_project_observations_curator_coordinate_access
    project.project_observations.joins(:observation).where( "observations.user_id = ?", user ).find_each do |po|
      po.set_curator_coordinate_access( force: true )
      po.save!
    end
  end

  def subscribe_to_assessment_sections
    AssessmentSection.joins(:assessment).where("assessments.project_id = ?", project).find_each do |as|
      Subscription.create(:resource => as, :user => user)
    end
  end
  
  def has_time_zone?
    user.time_zone?
  end
  
  def is_curator?
    role == 'curator' || is_manager? || is_admin?
  end
  
  def is_manager?
    role == 'manager' || is_admin?
  end
  
  def is_admin?
    user_id == project.user_id
  end

  def user_invited?
    return true unless project
    return true if project.preferred_membership_model == Project::MEMBERSHIP_OPEN
    return true if project.user_id == user_id
    uid = user_id || user.try(:id)
    pid = project_id || project.try(:id)
    unless ProjectUserInvitation.where(:invited_user_id => uid, :project_id => pid).exists?
      errors.add(:user, "hasn't been invited to this project")
    end
  end
  
  def update_observations_counter_cache
    update_attributes(:observations_count => project_observations.count)
  end
  
  # set taxa_count on project user, which is the number of taxa observed by this user, favoring the curator ident
  def update_taxa_counter_cache
    project.update_users_taxa_counts(user_id: user_id)
  end
  
  def check_role
    return true unless role_changed?
    if role_was.blank?
      Project.delay(:priority => USER_INTEGRITY_PRIORITY).update_curator_idents_on_make_curator(project_id, id)
    elsif role.blank?
      Project.delay(:priority => USER_INTEGRITY_PRIORITY).update_curator_idents_on_remove_curator(project_id, id)
    end
    true
  end

  def index_project
    project.elastic_index! if project
  end

  def self.update_observations_counter_cache_from_project_and_user(project_id, user_id)
    project_user = ProjectUser.where(project_id: project_id, user_id: user_id).first
    return unless project_user
    project_user.update_observations_counter_cache
  end
  
  def self.update_taxa_counter_cache_from_project_and_user(project_id, user_id)
    project_user = ProjectUser.where(project_id: project_id, user_id: user_id).first
    return unless project_user
    project_user.update_taxa_counter_cache
  end
  
  def self.update_taxa_obs_and_observed_taxa_count_after_update_observation(observation_id, user_id)
    unless obs = Observation.find_by_id(observation_id)
      return
    end
    unless usr = User.find_by_id(user_id)
      return
    end
    obs.project_observations.each do |po|
      project_user = ProjectUser.where(project_id: po.project_id, user_id: user_id).first
      if project_user
        project_user.update_taxa_counter_cache
        project_user.update_observations_counter_cache
        Project.update_observed_taxa_count(po.project_id)
      end
    end
  end
end
