class ProjectObservation < ActiveRecord::Base
  belongs_to :project
  belongs_to :observation
  belongs_to :curator_identification, :class_name => "Identification"
  validates_presence_of :project, :observation
  validate :observed_by_project_member?, :on => :create
  validates_rules_from :project, :rule_methods => [:observed_in_place?, :georeferenced?, :identified?, :in_taxon?, :on_list?]
  validates_uniqueness_of :observation_id, :scope => :project_id, :message => "already added to this project"
  
  after_create  :refresh_project_list
  after_destroy :refresh_project_list
  
  after_create  :update_observations_counter_cache_later
  after_destroy :update_observations_counter_cache_later
  
  after_create  :update_taxa_counter_cache_later
  after_destroy :update_taxa_counter_cache_later
  
  after_create  :update_project_observed_taxa_counter_cache_later
  after_destroy :update_project_observed_taxa_counter_cache_later

  after_create :destroy_project_invitations

  def to_s
    "<ProjectObservation project_id: #{project_id}, observation_id: #{observation_id}>"
  end
  
  def observed_by_project_member?
    unless project.project_users.exists?(:user_id => observation.user_id)
      errors.add(:observation_id, "must belong to a member of the project")
      return false
    end
    true
  end
  
  def refresh_project_list
    return true if observation.blank? || observation.taxon_id.blank?
    Project.delay(:priority => USER_INTEGRITY_PRIORITY).refresh_project_list(project_id, 
      :taxa => [observation.taxon_id], :add_new_taxa => id_was.nil?)
    true
  end
  
  def update_observations_counter_cache_later
    return true unless observation
    ProjectUser.delay(:priority => USER_INTEGRITY_PRIORITY).update_observations_counter_cache_from_project_and_user(project_id, observation.user_id)
    true
  end
  
  def update_taxa_counter_cache_later
    return true unless observation
    ProjectUser.delay(:priority => USER_INTEGRITY_PRIORITY).update_taxa_counter_cache_from_project_and_user(project_id, observation.user_id)
    true
  end
  
  def update_project_observed_taxa_counter_cache_later
    Project.delay(:priority => USER_INTEGRITY_PRIORITY).update_observed_taxa_count(project_id)
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
    !observation.latitude.blank? && !observation.longitude.blank?
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
