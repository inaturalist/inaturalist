class ProjectList < LifeList
  belongs_to :project
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
    listed_taxa = ListedTaxon.where(taxon_id: taxon_ids, list_id: target_list_id).
      includes(:list)
    listed_taxa.each do |lt|
      Rails.logger.info "[INFO #{Time.now}] ProjectList.refresh_with_project_observation, refreshing #{lt}"
      refresh_listed_taxon(lt)
    end
    Rails.logger.info "[INFO #{Time.now}] Finished ProjectList.refresh_with_project_observation for #{project_observation.id}"
    
    if taxon #if the observation has a curator_id
      if respond_to?(:create_new_listed_taxa_for_refresh)
        create_new_listed_taxa_for_refresh(taxon, listed_taxa, [target_list_id])
      end
    end
    Rails.logger.info "[INFO #{Time.now}] refresh_with_project_observation #{project_observation.id}, finished"
  end
  
  def self.refresh_with_observation_lists(observation, options = {})
    observation = Observation.find_by_id(observation) unless observation.is_a?(Observation)
    return [] unless observation.is_a?(Observation)
    project_ids, curator_identification_ids = observation.project_observations.
      map{|po| [po.project_id, po.curator_identification_id]}.transpose
    return [] if project_ids.nil?
    target_list_and_curator_ids = ProjectList.where(project_id: project_ids).select(:id).
      map{ |pl| pl.id }.zip(curator_identification_ids)
    #only update listed taxa if the project_observations have no curator_identification_ids
    #otherwise update these listed_taxa when the curator_identification_id on the project_observation changes
    target_list_and_curator_ids.map{|pair| pair[0] unless pair[1] }.compact
  end
  
  #todo, make this support options[:taxa] filtering
  def self.add_taxa_from_observations(list, options = {})
    sql = <<-SQL
      SELECT DISTINCT ON (taxon_id)
        CASE WHEN po.curator_identification_id IS NOT NULL THEN i.taxon_id ELSE observations.taxon_id END AS taxon_id, 
        observations.id
      FROM 
        observations
          JOIN project_observations po ON po.observation_id = observations.id
          LEFT OUTER JOIN identifications i ON i.id = po.curator_identification_id
      WHERE
        po.project_id = #{list.project_id}
        AND (observations.quality_grade = 'research' OR po.curator_identification_id IS NOT NULL)
    SQL
    scope = Observation
    scope = scope.of(list.rule_taxon) if list.rule_taxon
    scope = scope.in_place(list.place) if list.place
    results = scope.find_by_sql [sql]
    results.each do |observation|
      list.add_taxon(observation.taxon_id, :last_observation_id => observation.id) 
    end
  end
  
  def self.repair_observed(list)
    conditions = "po.project_id = ? AND (" +
      "(po.curator_identification_id IS NOT NULL AND i.taxon_id != listed_taxa.taxon_id) OR " +
      "(po.curator_identification_id IS NULL AND (o.quality_grade != 'research' OR o.taxon_id != listed_taxa.taxon_id)) " +
    ")"
    scope = ListedTaxon.where("list_id = ?", list)
    scope = scope.joins("LEFT OUTER JOIN observations o ON o.id = listed_taxa.last_observation_id").
    joins("LEFT OUTER JOIN project_observations po ON po.observation_id = listed_taxa.last_observation_id").
    joins("LEFT OUTER JOIN identifications i ON i.id = po.curator_identification_id").
    select("listed_taxa.id, CASE WHEN po.curator_identification_id IS NOT NULL THEN i.taxon_id ELSE o.taxon_id END AS taxon_id").
    where(conditions, list.project_id)
    scope.each do |entry|
      lt = ListedTaxon.find_by_id(entry.id)
      taxon = Taxon.find_by_id(entry.taxon_id)
      lt.destroy unless taxon.descendant_of?(lt.taxon)
    end
  end
  
  private
  def set_defaults
    self.title ||= I18n.t('project_list_defaults.title', owner_name: owner_name)
    self.description ||= I18n.t('project_list_defaults.description', owner_name: owner_name)
    true
  end
end
