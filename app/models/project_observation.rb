class ProjectObservation < ActiveRecord::Base
  belongs_to :project
  belongs_to :observation
  belongs_to :curator_identification, :class_name => "Identification"
  belongs_to :user
  validates_presence_of :project, :observation
  # validate :observed_by_project_member?, :on => :create, :unless => "errors.any?"
  validate :observer_allows_addition?
  validates_rules_from :project, :rule_methods => [
    :captive?,
    :wild?,
    :georeferenced?, 
    :has_media?,
    :has_a_photo?,
    :has_a_sound?,
    :identified?, 
    :in_taxon?, 
    :observed_in_place?, 
    :on_list?
  ], :unless => "errors.any?"
  validates_uniqueness_of :observation_id, :scope => :project_id, :message => "already added to this project"

  preference :usage_according_to_terms, :boolean, default: false
  before_create :set_usage_according_to_terms

  def set_usage_according_to_terms
    return true unless project_user
    self.preferred_usage_according_to_terms = project_user.preferred_usage_according_to_terms if preferred_usage_according_to_terms.nil?
  end

  def project_user
    project.project_users.where(user_id: observation.user_id).first
  end
  
  after_create  :refresh_project_list
  after_destroy :refresh_project_list
  
  after_create  :update_observations_counter_cache_later
  after_destroy :update_observations_counter_cache_later
  
  after_create  :update_taxa_counter_cache_later
  after_destroy :update_taxa_counter_cache_later
  
  after_create  :update_project_observed_taxa_counter_cache_later
  after_destroy :update_project_observed_taxa_counter_cache_later

  after_create :destroy_project_invitations, :update_curator_identification, :expire_caches
  after_destroy :expire_caches

  after_create  :touch_observation
  after_destroy :touch_observation
  
  after_save :update_project_list_if_curator_ident_changed
  
  def update_project_list_if_curator_ident_changed
    return true unless curator_identification_id_changed?
    old_curator_identification_id = curator_identification_id_was
    old_curator_identification = Identification.where(:id => old_curator_identification_id).first
    taxon_id = curator_identification ? curator_identification.taxon_id : nil
    if old_curator_identification 
      taxon_id_was = old_curator_identification.taxon_id
    else
      taxon_id_was = nil
    end
    # Don't refresh if nothing changed
    return true if taxon_id == taxon_id_was
    #if nil set taxon_id_was to observation.taxon_id so listings with this taxon_id will get refreshed
    taxon_id_was = Observation.find_by_id(observation_id).taxon_id if taxon_id_was.nil?
    # Update the projectobservation's current curator_id taxon and/or a previous one that was
    # just removed/changed
    unless Delayed::Job.where("handler LIKE '%ProjectList%refresh_with_project_observation% #{id}\n%'").exists?
      ProjectList.delay(:priority => USER_INTEGRITY_PRIORITY, :queue => "slow").
       refresh_with_project_observation(
         id,
         :observation_id => observation_id,
         :taxon_id => taxon_id,
         :taxon_id_was => taxon_id_was,
         :project_id => project_id
       )
    end
    true
  end
  
  def update_curator_identification
    return true if observation.new_record?
    return true if observation.owners_identification.blank?
    Identification.delay(:priority => INTEGRITY_PRIORITY).run_update_curator_identification(observation.owners_identification)
    true
  end

  def to_s
    "<ProjectObservation project_id: #{project_id}, observation_id: #{observation_id}>"
  end
  
  def observed_by_project_member?
    return false unless project
    unless project.project_users.exists?(:user_id => observation.user_id)
      errors.add(:observation_id, "must belong to a member of the project")
      return false
    end
    true
  end
  def observer_allows_addition?
    return unless observation
    return true if user_id == observation.user_id
    case observation.user.preferred_project_addition_by
    when User::PROJECT_ADDITION_BY_JOINED
      unless project.project_users.where(user_id: observation.user_id).exists?
        errors.add :user_id, "does not allow addition to projects they haven't joined"
      end
    when User::PROJECT_ADDITION_BY_NONE
      errors.add :user_id, "does not allow other people to add their observations to projects"
    end
  end
  
  def refresh_project_list
    return true if observation.blank? || observation.taxon_id.blank? || observation.bulk_import
    return true if Delayed::Job.where("handler LIKE '%Project%refresh_project_list% #{project_id}\n%'").exists?
    Project.delay(:priority => USER_INTEGRITY_PRIORITY, :queue => "slow", :run_at => 1.hour.from_now).refresh_project_list(project_id, 
      :taxa => [observation.taxon_id], :add_new_taxa => id_was.nil?)
    true
  end
  
  def update_observations_counter_cache_later
    return true unless observation
    return true if observation.bulk_import
    ProjectUser.delay(:priority => USER_INTEGRITY_PRIORITY).update_observations_counter_cache_from_project_and_user(project_id, observation.user_id)
    true
  end
  
  def update_taxa_counter_cache_later
    return true unless observation
    return true if observation.bulk_import
    ProjectUser.delay(:priority => USER_INTEGRITY_PRIORITY).update_taxa_counter_cache_from_project_and_user(project_id, observation.user_id)
    true
  end
  
  def update_project_observed_taxa_counter_cache_later
    return true if observation && observation.bulk_import
    Project.delay(:priority => USER_INTEGRITY_PRIORITY).update_observed_taxa_count(project_id)
    true
  end

  def expire_caches
    begin
      FileUtils.rm private_page_cache_path(FakeView.all_project_observations_path(project, :format => 'csv')), :force => true
    rescue ActionController::RoutingError
      FileUtils.rm private_page_cache_path(FakeView.all_project_observations_path(project_id, :format => 'csv')), :force => true
    end
    true
  end

  def destroy_project_invitations
    observation.project_invitations.where(:project_id => project).each(&:destroy)
    true
  end

  def to_csv_column(column, options = {})
    p = options[:project] || project
    case column
    when "curator_ident_taxon_id"
      curator_identification.try(:taxon_id)
    when "curator_ident_taxon_name"
      if curator_identification
        curator_identification.taxon.name
      else
        nil
      end
    when "curator_ident_user_id"
      curator_identification.try(:user_id)
    when "curator_ident_user_login"
      if curator_identification
        curator_identification.user.login
      else
        nil
      end
    when "usage_according_to_terms"
      preferred_usage_according_to_terms
    else
      if observation_field = p.observation_fields.detect{|of| of.name == column}
        observation.observation_field_values.detect{|ofv| ofv.observation_field_id == observation_field.id}.try(:value)
      else
        observation.send(column) rescue send(column) rescue nil
      end
    end
  end
  
  ##### Rules ###############################################################
  def observed_in_place?(place)
    place.contains_lat_lng?(
      observation.private_latitude || observation.latitude, 
      observation.private_longitude || observation.longitude)
  end
  
  def observed_in_bounding_box_of?(place)
    place.bbox_contains_lat_lng?(
      observation.private_latitude || observation.latitude, 
      observation.private_longitude || observation.longitude)
  end
  
  def georeferenced?
    observation.georeferenced?
  end
  
  def identified?
    !observation.taxon_id.blank?
  end
  
  def in_taxon?(taxon)
    return false if taxon.blank?
    return true if observation.taxon.blank?
    taxon.id == observation.taxon_id || taxon.ancestor_of?(observation.taxon)
  end
  
  def on_list?
    list = project.project_list
    return false if list.blank?
    return false if observation.taxon.blank?
    list.listed_taxa.detect{|lt| lt.taxon_id == observation.taxon_id}
  end

  def has_observation_field?(observation_field)
    observation.observation_field_values.where(:observation_field_id => observation_field).exists?
  end

  def has_a_photo?(options = {})
    observation.reload unless options[:skip_reload]
    observation.observation_photos_count > 0
  end

  def has_a_sound?(options = {})
    observation.reload unless options[:skip_reload]
    observation.observation_sounds_count > 0
  end

  def has_media?
    observation.reload
    has_a_photo?(:skip_reload => true) || has_a_sound?(:skip_reload => true)
  end

  def captive?
    observation.captive_cultivated
  end

  def wild?
    !captive?
  end

  def touch_observation
    observation.touch if observation
    true
  end
  
  ##### Static ##############################################################
  def self.to_csv(project_observations, options = {})
    return nil if project_observations.blank?
    project = options[:project] || project_observations.first.project
    columns = Observation::CSV_COLUMNS
    unless project.curated_by?(options[:user])
      columns -= %w(private_latitude private_longitude private_positional_accuracy)
    end
    headers = columns.map{|c| Observation.human_attribute_name(c)}

    project_columns = %w(curator_ident_taxon_id curator_ident_taxon_name curator_ident_user_id curator_ident_user_login tracking_code)
    columns += project_columns
    headers += project_columns.map{|c| c.to_s.humanize}

    ofv_columns = project.observation_fields.map(&:name)
    columns += ofv_columns
    headers += ofv_columns

    CSV.generate do |csv|
      csv << headers
      project_observations.each do |project_observation|
        csv << columns.map {|column| project_observation.to_csv_column(column, :project => project)}
      end
    end
  end
end
