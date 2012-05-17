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
  
  def cache_columns_query_for(lt)
    lt = ListedTaxon.find_by_id(lt) unless lt.is_a?(ListedTaxon)
    return nil unless lt
    ancestry_clause = [lt.taxon_ancestor_ids, lt.taxon_id].flatten.map{|i| i.blank? ? nil : i}.compact.join('/')
    sql_key = "EXTRACT(month FROM observed_on) || substr(quality_grade,1,1)"
    <<-SQL
      SELECT
        array_agg(o.id) AS ids,
        count(*),
        (#{sql_key}) AS key
      FROM
        observations o
          LEFT OUTER JOIN taxa t ON t.id = o.taxon_id
          LEFT OUTER JOIN project_observations po ON po.observation_id = o.id
      WHERE
        po.project_id = #{project_id} AND
        (
          o.taxon_id = #{lt.taxon_id} OR 
          t.ancestry LIKE '#{ancestry_clause}/%'
        )
      GROUP BY #{sql_key}
    SQL
  end
  
  def self.refresh_with_observation_lists(observation, options = {})
    observation = Observation.find_by_id(observation) unless observation.is_a?(Observation)
    return [] unless observation.is_a?(Observation)
    project_ids = observation.project_observations.map{|po| po.project_id}
    ProjectList.all(:select => "id", :conditions => ["project_id IN (?)", project_ids]).map{|pl| pl.id}
  end
  
  private
  def set_defaults
    self.title ||= "%s's Check List" % owner_name
    self.description ||= "The species list for #{owner_name}"
    true
  end
end
