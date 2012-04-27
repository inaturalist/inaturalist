class ProjectObservation < ActiveRecord::Base
  belongs_to :project
  belongs_to :observation
  belongs_to :curator_identification, :class_name => "Identification"
  validates_presence_of :project_id, :observation_id
  validate_on_create :observed_by_project_member?
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
  
  def observed_by_project_member?
    return false if project.blank? || observation.blank?
    project.project_users.exists?(:user_id => observation.user_id)
  end
  
  def refresh_project_list
    return true if observation.taxon_id.blank?
    Project.send_later(:refresh_project_list, project_id, 
      :taxa => [observation.taxon_id], :add_new_taxa => id_was.nil?)
    true
  end
  
  def update_observations_counter_cache_later
    ProjectUser.send_later(:update_observations_counter_cache_from_project_and_user, project_id, observation.user_id)
    true
  end
  
  def update_taxa_counter_cache_later
    ProjectUser.send_later(:update_taxa_counter_cache_from_project_and_user, project_id, observation.user_id)
    true
  end
  
  def update_project_observed_taxa_counter_cache_later
    Project.send_later(:update_observed_taxa_count, project_id)
  end

  def to_csv_column(column)
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
      observation.send(column) rescue send(column)
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
  
  ##### Static ##############################################################
  def self.to_csv(project_observations, options = {})
    return nil if project_observations.blank?
    project = options[:project] || project_observations.first.project
    columns = Observation.column_names
    columns += [:scientific_name, :common_name, :url, :image_url, :tag_list, :user_login].map{|c| c.to_s}
    except = [:map_scale, :timeframe, :iconic_taxon_id, :delta, :user_agent, :location_is_exact, :geom].map{|e| e.to_s}
    unless project.curated_by?(options[:user])
      except += %w(private_latitude private_longitude private_positional_accuracy)
    end
    columns -= except
    headers = columns.map{|c| Observation.human_attribute_name(c)}
    project_columns = %w(curator_ident_taxon_id curator_ident_taxon_name curator_ident_user_id curator_ident_user_login tracking_code)
    columns += project_columns
    headers += project_columns.map{|c| c.to_s.humanize}
    FasterCSV.generate do |csv|
      csv << headers
      project_observations.each do |project_observation|
        csv << columns.map {|column| project_observation.to_csv_column(column)}
      end
    end
  end
end
