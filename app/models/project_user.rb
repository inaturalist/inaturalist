class ProjectUser < ApplicationRecord
  
  belongs_to :project, inverse_of: :project_users, touch: true
  belongs_to :user, touch: true
  auto_subscribes :user, :to => :project
  
  after_save :check_role,
             :remove_updates,
             :subscribe_to_assessment_sections_later,
             :update_project_observations_later
  after_commit :index_project, on: [:create, :update]
  after_destroy :remove_updates
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
  # Specifies whether curators can see hidden coordinates based on who added the observation to the project
  preference :curator_coordinate_access, :string, :default => CURATOR_COORDINATE_ACCESS_OBSERVER

  # Specifies whether curators can see hidden coordinates based on why the coordinates were hidden
  CURATOR_COORDINATE_ACCESS_FOR_NONE = "none"     # Curators cannot view hidden coords
  CURATOR_COORDINATE_ACCESS_FOR_TAXON = "taxon"   # Curators can view coords hidden by threatened taxon
  CURATOR_COORDINATE_ACCESS_FOR_ANY = "any"       # Curators can view coords hidden for any reason
  preference :curator_coordinate_access_for, :string, default: CURATOR_COORDINATE_ACCESS_FOR_NONE

  # The period of time a collection project curator must wait between changing
  # the observation requirements and accessing hidden coordinates
  CURATOR_COORDINATE_ACCESS_WAIT_PERIOD = 1.week

  preference :updates, :boolean, :default => true
  
  CURATOR_CHANGE_NOTIFICATION = "curator_change"
  ROLES = %w(curator manager)
  ROLES.each do |role|
    const_set role.upcase, role
    scope role.pluralize, -> { where(:role => role) }
  end

  notifies_subscribers_of :project, on: :save, notification: CURATOR_CHANGE_NOTIFICATION,
    include_notifier: true,
    # don't bother queuing this if there's no relevant role change
    queue_if: Proc.new{ |pu|
      !pu.project.is_new_project? &&
        pu.previous_changes[:role] &&
        ( ROLES.include?(pu.role) || pu.user_id == pu.project.user_id )
    },
    # check to make sure role status hasn't changed since queuing
    if: Proc.new{ |pu|
      !pu.project.is_new_project? &&
        ( ROLES.include?(pu.role) || pu.user_id == pu.project.user_id )
    }

  scope :curator_privilege, -> { where("role IN ('curator', 'manager')") }

  def to_s
    "<ProjectUser #{id} project: #{project_id} user: #{user_id} role: #{role}>"
  end

  def project_observations
    project.project_observations.joins(:observation).where(observations: { user_id: user_id })
  end

  def remove_updates
    return true unless saved_change_to_role? && role.blank?
    UpdateAction.delete_and_purge(
      notifier_type: "ProjectUser",
      notifier_id: id,
      resource_type: "Project",
      resource_id: project_id)
    true
  end

  def subscribe_to_assessment_sections_later
    return true unless saved_change_to_role? && !role.blank?
    delay(:priority => USER_INTEGRITY_PRIORITY).subscribe_to_assessment_sections
    true
  end

  def update_project_observations_later
    return true unless preferred_curator_coordinate_access_changed?
    delay( priority: USER_INTEGRITY_PRIORITY ).update_project_observations_curator_coordinate_access
    true
  end

  def update_project_observations_curator_coordinate_access
    Observation.search_in_batches( project_id: project_id, user_id: user_id ) do |batch|
      Observation.preload_associations( batch, [:project_observations] )
      project_observations = batch.collect{|o| o.project_observations.select{|po| po.project_id == project_id }}.flatten
      project_observations.each do |po|
        po.set_curator_coordinate_access( force: true )
        unless po.save
          Rails.logger.error "[ERROR #{Time.now}] Failed to update #{po}: #{po.errors.full_messages.to_sentence}"
        end
      end
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
    return true if project.is_new_project?
    return true if project.preferred_membership_model == Project::MEMBERSHIP_OPEN
    return true if project.user_id == user_id
    uid = user_id || user.try(:id)
    pid = project_id || project.try(:id)
    unless ProjectUserInvitation.where(:invited_user_id => uid, :project_id => pid).exists?
      errors.add(:user, "hasn't been invited to this project")
    end
  end

  def update_observations_counter_cache
    project.update_users_observations_counts(user_id: user_id)
  end

  def update_taxa_counter_cache
    project.update_users_taxa_counts(user_id: user_id)
  end

  def check_role
    return true unless saved_change_to_role?
    # TODO Rails 6: use role_previously_was?
    if previous_changes[:role] && previous_changes[:role][0].blank?
      Project.delay(:priority => USER_INTEGRITY_PRIORITY).update_curator_idents_on_make_curator(project_id, id)
    elsif role.blank?
      Project.delay(:priority => USER_INTEGRITY_PRIORITY).update_curator_idents_on_remove_curator(project_id, id)
    end
    true
  end

  def index_project
    project.elastic_index! if project && !project.skip_indexing
  end

  def as_indexed_json
    {
      id: id,
      user_id: user_id,
      project_id: project_id,
      role: role
    }
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

  # This will remove all duplicates by grouping on project_id and user_id.
  # Probably only useful when it gets used by User.merge, otherwise probably
  # rather dangerous
  def self.merge_duplicates( options = {} )
    debug = options.delete(:debug)
    where = options.map{|k,v| "#{k} = #{v}"}.join(" AND ") unless options.blank?
    sql = <<-SQL
      SELECT project_id, user_id, array_agg(id) AS ids, count(*)
      FROM project_users
      #{"WHERE #{where}" if where}
      GROUP BY project_id, user_id HAVING count(*) > 1
    SQL
    puts "Finding project_users WHERE #{where}" if debug
    connection.execute( sql.gsub(/\s+/, " " ).strip ).each do |row|
      to_merge_ids = row["ids"].to_s.gsub( /[\{\}]/, "" ).split( "," ).sort
      pu = ProjectUser.find_by_id( to_merge_ids.first )
      puts "pu: #{pu}, merging #{to_merge_ids}" if debug
      rejects = ProjectUser.where( id: to_merge_ids[1..-1] )
      rejects.destroy_all
    end
  end

  def self.merge_future_duplicates( reject, keeper )
    Rails.logger.debug "[DEBUG] ProjectUser.merge_future_duplicates, reject: #{reject}, keeper: #{keeper}"
    unless reject.is_a?( keeper.class )
      raise "reject and keeper must by of the same class"
    end
    unless reject.is_a?( User )
      raise "ProjectUser.merge_future_duplicates only works for observations right now"
    end
    k, reflection = reflections.detect{|k,r| r.klass == reject.class && r.macro == :belongs_to }
    sql = <<-SQL
      SELECT
        project_id,
        array_agg(id) AS ids
      FROM
        project_users
      WHERE
        #{reflection.foreign_key} IN (#{reject.id},#{keeper.id})
      GROUP BY
        project_id
      HAVING
        count(*) > 1
    SQL
    connection.execute( sql.gsub(/\s+/, " " ).strip ).each do |row|
      to_merge_ids = row['ids'].to_s.gsub(/[\{\}]/, '').split(',').sort
      project_users = ProjectUser.where( id: to_merge_ids )
      if reject_pu = project_users.detect{|i| i.send(reflection.foreign_key) == reject.id }
        reject_pu.destroy
      end
    end
  end
end
