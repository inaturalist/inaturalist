class ProjectObservation < ActiveRecord::Base
  blockable_by lambda {|po| po.observation.try(:user_id) }

  belongs_to :project
  belongs_to_with_uuid :observation
  belongs_to :curator_identification, :class_name => "Identification"
  belongs_to :user
  validates_presence_of :project, :observation
  validate :observer_allows_addition?
  validate :project_allows_submitter?
  validate :observer_invited?
  validate :project_allows_observations?
  validate :required_observation_fields_present?
  validates_rules_from :project, :rule_methods => [
    :captive?,
    :coordinates_shareable_by_project_curators?,
    :georeferenced?, 
    :has_a_photo?,
    :has_a_sound?,
    :has_media?,
    :identified?, 
    :in_taxon?, 
    :observed_in_place?,
    :on_list?,
    :verifiable?,
    :wild?
  ], :unless => "errors.any?"
  validate :observed_in_bioblitz_time_range?
  validates_uniqueness_of :observation_id, :scope => :project_id, :message => "already added to this project"

  preference :curator_coordinate_access, :boolean, default: nil
  before_validation :set_curator_coordinate_access

  notifies_owner_of :observation, 
    queue_if: lambda { |record| record.user_id != record.observation.user_id },
    with: :notify_observer

  include ActsAsUUIDable

  def notify_observer(association)
    return if CONFIG.has_subscribers == :disabled
    return unless observation
    existing_project_updates = UpdateAction.elastic_paginate(
      filters: [
        { term: { notification: UpdateAction::YOUR_OBSERVATIONS_ADDED } },
        { term: { subscriber_ids: observation.user_id } }
      ],
      inverse_filters: [
        { term: { viewed_subscriber_ids: observation.user_id } }
      ],
      per_page: 1 )
    return if existing_project_updates && existing_project_updates.total_entries >= 15
    action_attrs = {
      resource: project,
      notifier: self,
      notification: UpdateAction::YOUR_OBSERVATIONS_ADDED
    }
    if action = UpdateAction.first_with_attributes(action_attrs)
      action.append_subscribers( [observation.user.id] )
    end
  end
  
  after_destroy do |record|
    UpdateAction.where(resource: record.project, notifier: observation,
      notification: UpdateAction::YOUR_OBSERVATIONS_ADDED).delete_all
  end

  def set_curator_coordinate_access( options = {} )
    return unless observation
    return true unless preferred_curator_coordinate_access.nil? || options[:force]
    if project_user
      self.preferred_curator_coordinate_access = case project_user.preferred_curator_coordinate_access
      when ProjectUser::CURATOR_COORDINATE_ACCESS_OBSERVER
        user_id == observation.user_id
      when ProjectUser::CURATOR_COORDINATE_ACCESS_ANY
        true
      else
        false
      end
    end
    self.preferred_curator_coordinate_access = false if preferred_curator_coordinate_access.nil?
    true
  end

  def project_user
    return unless project
    project.project_users.where(user_id: observation.user_id).first
  end

  after_create  :update_observations_counter_cache_later
  after_destroy :update_observations_counter_cache_later

  after_create  :update_taxa_counter_cache_later
  after_destroy :update_taxa_counter_cache_later

  after_create  :update_project_observed_taxa_counter_cache_later
  after_destroy :update_project_observed_taxa_counter_cache_later

  after_create :destroy_project_invitations, :update_curator_identification, :expire_caches
  after_destroy :expire_caches

  after_create :revisit_curator_identifications_later

  attr_accessor :skip_touch_observation

  include Shared::TouchesObservationModule

  def reindex_observation
    Observation.elastic_index!( ids: [observation_id] ) if observation
  end
  
  def update_curator_identification
    return true if observation.new_record?
    return true if observation.owners_identification.blank?
    observation.owners_identification.update_curator_identification
    true
  end

  def to_s
    "<ProjectObservation project_id: #{project_id}, observation_id: #{observation_id}>"
  end

  def observer_allows_addition?
    return unless observation
    return true if user_id == observation.user_id
    case observation.user.preferred_project_addition_by
    when User::PROJECT_ADDITION_BY_JOINED
      unless project && project.project_users.where(user_id: observation.user_id).exists?
        errors.add :user_id, "does not allow addition to projects they haven't joined"
        return false
      end
    when User::PROJECT_ADDITION_BY_NONE
      errors.add :user_id, "does not allow other people to add their observations to projects"
      return false
    end
    true
  end

  def project_allows_submitter?
    return unless project
    return true if project.preferred_submission_model == Project::SUBMISSION_BY_ANYONE
    return true unless user
    if project.curated_by?(user)
      true
    else
      errors.add :user_id, :must_be_curator
      false
    end
  end

  def project_allows_observations?
    if project && project.is_new_project?
      errors.add :base, :collection_and_umbrella_projects_do_not_allow_direct_submission
    end
  end

  def observer_invited?
    return unless project
    return unless observation
    return true unless project.invite_only?
    return true if project.project_users.where(user_id: observation.user_id).exists?
    return true if project.project_user_invitations.where(invited_user_id: observation.user_id).exists?
    errors.add :observation_id, "must be made by a project member or an invited user"
    false
  end

  def observed_in_bioblitz_time_range?
    if project && observation && project.bioblitz?
      if project.start_time && !observed_after?(project.preferred_start_date_or_time)
        errors.add :observation_id, :must_be_observed_after,
          time: I18n.l(project.preferred_start_date_or_time)
      elsif project.end_time && !observed_before?(project.preferred_end_date_or_time)
        errors.add :observation_id, :must_be_observed_before,
          time: I18n.l(project.preferred_end_date_or_time)
      end
    end
  end

  # Required observation fields are validated as rules, but rules are valid if
  # *any* of them pass, while required observation fields should *all* be
  # present
  def required_observation_fields_present?
    return true if !project
    required_pofs = project.project_observation_fields.select(&:required?)
    return true if required_pofs.size < 2
    missing = required_pofs.detect do |pof|
      !observation.observation_field_values.detect do |ofv|
        ofv.observation_field_id == pof.observation_field_id
      end
    end
    return true unless missing
    errors.add(:base, "Missing required observation field: #{missing.observation_field.name}" )
    false
  end
  
  def update_observations_counter_cache_later
    return true unless observation
    return true if observation.bulk_import || observation.bulk_delete
    ProjectUser.delay(priority: USER_INTEGRITY_PRIORITY,
      unique_hash: { "ProjectUser::update_observations_counter_cache_from_project_and_user":
        [ project_id, observation.user_id ] }
    ).update_observations_counter_cache_from_project_and_user(project_id, observation.user_id)
    true
  end
  
  def update_taxa_counter_cache_later
    return true unless observation
    return true if observation.bulk_import || observation.bulk_delete
    ProjectUser.delay(priority: USER_INTEGRITY_PRIORITY,
      unique_hash: { "ProjectUser::update_taxa_counter_cache_from_project_and_user":
        [ project_id, observation.user_id ] }
    ).update_taxa_counter_cache_from_project_and_user(project_id, observation.user_id)
    true
  end
  
  def update_project_observed_taxa_counter_cache_later
    return true if observation && ( observation.bulk_import || observation.bulk_delete )
    Project.delay(priority: USER_INTEGRITY_PRIORITY,
      unique_hash: { "Project::update_observed_taxa_count": project_id }
    ).update_observed_taxa_count(project_id)
    true
  end

  def revisit_curator_identifications_later
    return true if observation && ( observation.bulk_import || observation.bulk_delete )
    observation.identifications.each do |i|
      i.update_curator_identification
    end
    true
  end

  def expire_caches
    return true if project_id.blank?
    begin
      FileUtils.rm private_page_cache_path(FakeView.all_project_observations_path(project, :format => 'csv')), :force => true
    rescue ActionController::RoutingError, ActionController::UrlGenerationError
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
    when "curator_coordinate_access"
      preferred_curator_coordinate_access
    else
      if column.to_s =~ /private_/
        if observation && observation.coordinates_viewable_by?(options[:viewer])
          observation.send(column)
        else
          nil
        end
      elsif observation_field = p.observation_fields.detect{|of| of.normalized_name == ObservationField.normalize_name( column )}
        observation.observation_field_values.detect{|ofv| ofv.observation_field_id == observation_field.id}.try(:value)
      else
        observation.send(column) rescue send(column) rescue nil
      end
    end
  end
  
  ##### Rules ###############################################################
  def observed_in_place?(place = nil)
    return false if place.blank?
    place.contains_lat_lng?(
      observation.private_latitude || observation.latitude,
      observation.private_longitude || observation.longitude)
  end
  
  def observed_in_bounding_box_of?(place = nil)
    return false if place.blank?
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
  
  def in_taxon?(taxon = nil)
    return false if taxon.blank?
    return true if observation.taxon.blank?
    taxon.id == observation.taxon_id || taxon.ancestor_of?(observation.taxon)
  end

  def not_in_taxon?(taxon = nil)
    !in_taxon?( taxon )
  end
  
  def on_list?
    list = project.project_list
    return false if list.blank?
    return false if observation.taxon.blank?
    list.listed_taxa.detect{|lt| lt.taxon_id == observation.taxon_id}
  end

  def has_observation_field?(observation_field = nil)
    return false if observation_field.blank?
    observation.observation_field_values.where(:observation_field_id => observation_field).exists?
  end

  def has_a_photo?(options = {})
    observation.reload unless options[:skip_reload]
    observation.observation_photos.count > 0
  end

  def has_a_sound?(options = {})
    observation.reload unless options[:skip_reload]
    observation.observation_sounds.count > 0
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

  def verifiable?
    observation.verifiable?
  end

  def coordinates_shareable_by_project_curators?
    prefers_curator_coordinate_access?
  end

  def removable_by?(usr)
    return true if [user_id, observation.user_id].include?(usr.id)
    return true if project.curated_by?(usr)
    false
  end

  def observed_after?(time = nil)
    obs_time = observation.time_observed_at_in_zone || observation.observed_on
    return false if !obs_time
    if project.prefers_range_by_date?
      return true if time && obs_time.to_date >= time.to_date
    else
      return true if time && obs_time >= time
    end
    false
  end

  def observed_before?(time = nil)
    obs_time = observation.time_observed_at_in_zone || observation.observed_on
    return false if !obs_time
    if project.prefers_range_by_date?
      return true if time && obs_time.to_date <= time.to_date
    else
      return true if time && obs_time <= time
    end
    false
  end

  def in_project?(rule_project = nil)
    return true if project.is_new_project?
    false
  end

  def observed_by_user?(user = nil)
    return true if project.is_new_project?
    false
  end

  def touch_observation
    return if skip_touch_observation
    if observation
      observation.project_observations.reload
      observation.touch
    end
  end

  def as_indexed_json
    {
      id: id,
      uuid: uuid,
      project_id: project_id,
      user_id: user_id,
      preferences: preferences.map{ |p| { name: p[0], value: p[1] } }
    }
  end

  ##### Static ##############################################################
  def self.to_csv(project_observations, options = {})
    return nil if project_observations.blank?
    project = options[:project] || project_observations.first.project
    columns = Observation::CSV_COLUMNS
    unless project.curated_by?(options[:user])
      columns -= %w(private_latitude private_longitude private_place_guess)
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
