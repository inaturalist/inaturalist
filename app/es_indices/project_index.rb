class Project < ActiveRecord::Base
  include ActsAsElasticModel

  DEFAULT_ES_BATCH_SIZE = 500

  scope :load_for_index, -> { includes(
    :flags,
    :user,
    :place,
    :project_users,
    :observation_fields,
    { project_observation_rules: :operand },
    :stored_preferences,
    :site_featured_projects,
    :project_observation_rules_as_operand
  ) }

  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :admins do
        indexes :id, type: "integer", index: false
        indexes :project_id, type: "integer", index: false
        indexes :role, type: "keyword", index: false
        indexes :user_id, type: "integer", index: false
      end
      indexes :ancestor_place_ids, type: "integer"
      indexes :associated_place_ids, type: "integer"
      indexes :banner_color, type: "keyword", index: false
      indexes :created_at, type: "date"
      indexes :description, analyzer: "ascii_snowball_analyzer"
      indexes :flags do
        indexes :comment, type: "keyword", index: false
        indexes :created_at, type: "date", index: false
        indexes :flag, type: "keyword", index: false
        indexes :id, type: "integer", index: false
        indexes :resolved, type: "boolean", index: false
        indexes :resolver_id, type: "integer", index: false
        indexes :updated_at, type: "date", index: false
        indexes :user_id, type: "integer", index: false
      end
      indexes :geojson, type: "geo_shape"
      indexes :header_image_contain, type: "boolean", index: false
      indexes :header_image_file_name, type: "keyword", index: false
      indexes :header_image_url, type: "keyword", index: false
      indexes :hide_title, type: "boolean", index: false
      indexes :icon, type: "keyword", index: false
      indexes :icon_file_name, type: "keyword", index: false
      indexes :id, type: "integer"
      indexes :last_post_at, type: "date"
      indexes :location, type: "geo_point"
      indexes :observations_count, type: "integer"
      indexes :place_id, type: "integer"
      indexes :place_ids, type: "integer"
      indexes :project_observation_fields do
        indexes :id, type: "integer"
        indexes :observation_field do
          indexes :allowed_values, type: "keyword"
          indexes :datatype, type: "keyword"
          indexes :description, type: "text", analyzer: "ascii_snowball_analyzer"
          indexes :description_autocomplete, type: "text",
            analyzer: "autocomplete_analyzer",
            search_analyzer: "standard_analyzer"
          indexes :id, type: "integer"
          indexes :name, type: "text", analyzer: "ascii_snowball_analyzer"
          indexes :name_autocomplete, type: "text",
            analyzer: "autocomplete_analyzer",
            search_analyzer: "standard_analyzer"
          indexes :users_count, type: "integer"
          indexes :values_count, type: "integer"
        end
        indexes :position, type: "short"
        indexes :required, type: "boolean"
      end
      indexes :prefers_user_trust, type: "boolean"
      indexes :project_observation_rules, type: :nested do
        indexes :id, type: "integer"
        indexes :operand_id, type: "integer"
        indexes :operator, type: "keyword"
        indexes :operand_type, type: "keyword"
      end
      indexes :project_type, type: "keyword"
      indexes :rule_place_ids, type: "integer"
      indexes :rule_preferences, type: :nested do
        indexes :field, type: "keyword"
        indexes :value, type: "text"
      end
      indexes :observation_requirements_updated_at, type: "date", index: false
      indexes :search_parameter_fields do
        indexes :d1, type: "date", format: "dateOptionalTime"
        indexes :d2, type: "date", format: "dateOptionalTime"
        indexes :d2_date, type: "date", format: "yyyy-MM-dd"
        indexes :introduced, type: "boolean"
        indexes :month, type: "byte"
        indexes :native, type: "boolean"
        indexes :not_in_place, type: "integer"
        indexes :not_user_id, type: "integer"
        indexes :observed_on, type: "date", format: "dateOptionalTime"
        indexes :photos, type: "boolean"
        indexes :place_id, type: "integer"
        indexes :project_id, type: "integer"
        indexes :quality_grade, type: "keyword"
        indexes :sounds, type: "boolean"
        indexes :taxon_id, type: "integer"
        indexes :term_id, type: "integer"
        indexes :term_value_id, type: "integer"
        indexes :user_id, type: "integer"
        indexes :without_taxon_id, type: "integer"
      end
      indexes :search_parameters, type: :nested do
        indexes :field, type: "keyword"
        indexes :value, type: "text"
        indexes :value_bool, type: "boolean"
        indexes :value_date, type: "date", format: "dateOptionalTime"
        indexes :value_keyword, type: "keyword"
        indexes :value_number, type: "long"
      end
      indexes :site_features, type: :nested do
        indexes :featured_at, type: "date"
        indexes :noteworthy, type: "boolean"
        indexes :site_id, type: "short"
        indexes :updated_at, type: "date"
      end
      indexes :slug, analyzer: "keyword_analyzer"
      indexes :spam, type: "boolean"
      indexes :subproject_ids, type: "integer"
      indexes :terms, type: "text", index: false
      indexes :title, analyzer: "ascii_snowball_analyzer"
      indexes :title_autocomplete, analyzer: "autocomplete_analyzer",
        search_analyzer: "standard_analyzer"
      indexes :title_exact, type: "keyword"
      indexes :universal_search_rank, type: "integer"
      indexes :umbrella_project_ids, type: "integer"
      indexes :updated_at, type: "date"
      indexes :user_id, type: "integer"
      indexes :user_ids, type: "integer"
    end
  end

  def as_indexed_json(options={})
    preload_for_elastic_index
    project_user_ids = project_users.map(&:user_id).uniq.sort
    # preload subproject rules to save queries when indexing large umbrellas
    # sometimes the rule operands aren't preloaded for some reason
    if project_observation_rules.length > 0 && !project_observation_rules.first.association(:operand).loaded?
      Project.preload_associations( project_observation_rules, [:operand])
    end
    Project.preload_associations(
      project_observation_rules.select { |r| r.operand_type == "Project" }.map( &:operand ),
      [{ project_observation_rules: :operand }, :place]
    )
    # This will effect search rankings, so first we try to get a count of obs by
    # people who have joined the project. Otherwise you could get a high-ranking
    # project just by using an expansive set of obs requirements.
    obs_count = begin
      r = INatAPIService.observations(
        project_id: id,
        user_id: project_user_ids.join( "," ),
        only_id: true,
        per_page: 0
      )
      # However, querying a lot of user_ids might fail or timeout, so we fall
      # back to just the count of obs, no user filter
      unless r
        r = INatAPIService.observations(
          project_id: id,
          only_id: true,
          per_page: 0
        )
      end
      # If for some reason that failed, set it to zero
      r ? r.total_results.to_i : 0
    rescue
      # And if we get an exception for any reason, don't break indexing, just
      # set the count to zero
      0
    end
    json = {
      id: id,
      title: title,
      title_autocomplete: title,
      title_exact: title,
      hide_title: !!prefers_hide_title,
      description: description,
      slug: slug,
      project_type: project_type,
      banner_color: preferred_banner_color,
      ancestor_place_ids: place ? place.ancestor_place_ids : nil,
      place_ids: place ? place.self_and_ancestor_ids : nil,
      place_id: rule_place_ids.first,
      user_id: user_id,
      admins: project_users.select{ |pu| !pu.role.blank? }.uniq.map(&:as_indexed_json),
      rule_place_ids: rule_place_ids,
      associated_place_ids: associated_place_ids,
      user_ids: project_user_ids,
      location: ElasticModel.point_latlon(latitude, longitude),
      geojson: ElasticModel.point_geojson(latitude, longitude),
      icon: icon ? FakeView.asset_url( icon.url(:span2), host: Site.default.url ) : nil,
      icon_file_name: icon_file_name,
      header_image_url: cover.blank? ? nil : FakeView.asset_url( cover.url, host: Site.default.url ),
      header_image_file_name: cover_file_name,
      header_image_contain: !!preferred_banner_contain,
      project_observation_fields: project_observation_fields.uniq.map(&:as_indexed_json),
      terms: terms.blank? ? nil : terms,
      search_parameters: collection_search_parameters.map{ |field,value|
        type = "keyword"
        if [ "d1", "d2", "observed_on" ].include?( field )
          type = "date"
        else
          instance = value.is_a?( Array ) ? value[0] : value
          if instance.is_a?( TrueClass ) || instance.is_a?( FalseClass )
            type = "bool"
          elsif instance.is_a?( Integer )
            type = "number"
          end
        end
        doc = {
          field: field,
          value: value
        }
        doc[:"value_#{type}"] = value
        doc
      },
      search_parameter_fields: collection_search_parameters,
      subproject_ids: project_type === "umbrella" ? project_observation_rules.select{ |rule|
        rule.operator == "in_project?"
      }.map( &:operand_id ) : [],
      project_observation_rules: project_observation_rules.map{ |rule| {
        id: rule.id,
        operator: rule.operator,
        operand_type: rule.operand_type,
        operand_id: rule.operand_id
      } }.uniq,
      rule_preferences: preferences.
        select{ |k,v| Project::RULE_PREFERENCES.include?(k) && !(v.blank? && v != false) }.
        map{ |k,v| { field: k.sub("rule_",""), value: v } },
      created_at: created_at,
      updated_at: updated_at,
      last_post_at: posts.published.last.try(:published_at),
      observations_count: obs_count,
      # Giving a search boost to featured projects, ensuring the value is larger than ES integer
      universal_search_rank: [
        ( obs_count + project_user_ids.size ) * ( site_featured_projects.size > 0 ? 10000 : 1 ),
        ( 2 ** 31 ) - 1
      ].min,
      spam: known_spam? || owned_by_spammer?,
      flags: flags.map(&:as_indexed_json),
      site_features: site_featured_projects.map(&:as_indexed_json),
      umbrella_project_ids: within_umbrella_ids,
      prefers_user_trust: prefers_user_trust,
      observation_requirements_updated_at: observation_requirements_updated_at
    }
    if project_type == "umbrella"
      json[:hide_umbrella_map_flags] = !!prefers_hide_umbrella_map_flags
    end
    json
  end

end
