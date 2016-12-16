class ProjectList < List
  belongs_to :project
  before_validation :set_defaults
  validates_presence_of :project_id
  
  def owner
    project
  end
  
  def owner_name
    project.title
  end
  
  def listed_taxa_editable_by?(user)
    return false if user.blank?
    project.project_users.exists?(:user_id => user)
  end
  
  # Curators and admins can alter the list.
  def editable_by?(user)
    return false if user.blank?
    project.project_users.exists?(["role IN ('curator', 'manager') AND user_id = ?", user])
  end

  def cache_columns_options(lt)
    lt = ListedTaxon.find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return nil unless lt
    { search_params: {
        where: {
          "taxon.ancestor_ids": lt.taxon_id,
          project_ids: project_id
        }
      },
      earliest_sort_field: "id",
      range_wheres: { quality_grade: :research } }
  end

  def self.refresh_with_project_observation(project_observation, options = {})
    Rails.logger.info "[INFO #{Time.now}] Starting ProjectList.refresh_with_project_observation for #{project_observation}, #{options.inspect}"
    project_observation = ProjectObservation.find_by_id(project_observation) unless project_observation.is_a?(ProjectObservation)
    unless observation = Observation.find_by_id(options[:observation_id])
      Rails.logger.error "[ERROR #{Time.now}] ProjectList.refresh_with_project_observation " + 
        "failed with blank observation, project_observation: #{project_observation}, options: #{options.inspect}"
      return
    end
    taxon = Taxon.find_by_id(options[:taxon_id])
    if taxon.nil?
      taxon_ids = []
    else
      taxon_ids = [taxon.ancestor_ids, taxon.id].flatten
    end
    if taxon_was = Taxon.find_by_id(options[:taxon_id_was])
      taxon_ids = [taxon_ids, taxon_was.ancestor_ids, taxon_was.id].flatten.uniq
    end
    unless project = Project.find_by_id(options[:project_id])
      Rails.logger.error "[ERROR #{Time.now}] ProjectList.refresh_with_project_observation " + 
        "failed with blank project, project_observation: #{project_observation}, options: #{options.inspect}"
      return
    end
    target_list_id = ProjectList.where(:project_id => project.id).first.id
    # get listed taxa for this taxon and its ancestors that are on the project list
    listed_taxa = ListedTaxon.where(taxon_id: taxon_ids, list_id: target_list_id).includes(:list)
    listed_taxa.each do |lt|
      Rails.logger.info "[INFO #{Time.now}] ProjectList.refresh_with_project_observation, refreshing #{lt}"
      refresh_listed_taxon(lt)
    end
    Rails.logger.info "[INFO #{Time.now}] Finished ProjectList.refresh_with_project_observation for #{project_observation.id}"    
  end 
  
  def self.refresh_with_observation_lists(observation, options = {})
    observation = Observation.find_by_id(observation) unless observation.is_a?(Observation)
    return [] unless observation.is_a?(Observation)
    project_ids = observation.project_observations.map{|po| po.project_id}
    return [] if project_ids.nil?
    target_list = ProjectList.where(project_id: project_ids).select(:id)
  end
    
  private
  def set_defaults
    self.title ||= I18n.t('project_list_defaults.title', owner_name: owner_name)
    self.description ||= I18n.t('project_list_defaults.description', owner_name: owner_name)
    true
  end
end
