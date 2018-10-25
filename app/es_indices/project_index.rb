class Project < ActiveRecord::Base
  include ActsAsElasticModel

  DEFAULT_ES_BATCH_SIZE = 500

  scope :load_for_index, -> { includes(
    :flags,
    :user,
    :place,
    :project_users,
    :observation_fields,
    :project_observation_rules,
    :stored_preferences,
    :site_featured_projects
  ) }

  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :icon, type: "keyword", index: false
      indexes :title, analyzer: "ascii_snowball_analyzer"
      indexes :title_autocomplete, analyzer: "autocomplete_analyzer",
        search_analyzer: "standard_analyzer"
      indexes :title_exact, type: "keyword"
      indexes :description, analyzer: "ascii_snowball_analyzer"
      indexes :slug, analyzer: "keyword_analyzer"
      indexes :project_type, type: "keyword"
      indexes :location, type: "geo_point"
      indexes :geojson, type: "geo_shape"
      indexes :terms, type: "text", index: false
      indexes :search_parameters, type: :nested do
        indexes :field, type: "keyword"
        indexes :value, type: "text"
        indexes :value_date, type: "date", format: "dateOptionalTime"
        indexes :value_boolean, type: "boolean"
        indexes :value_number, type: "long"
        indexes :value_keyword, type: "keyword"
      end
      indexes :search_parameter_fields do
        indexes :d1, type: "date", format: "dateOptionalTime"
        indexes :d2, type: "date", format: "dateOptionalTime"
        indexes :observed_on, type: "date", format: "dateOptionalTime"
        indexes :photos, type: "boolean"
        indexes :sounds, type: "boolean"
        indexes :taxon_id, type: "long"
        indexes :place_id, type: "long"
        indexes :user_id, type: "long"
        indexes :project_id, type: "long"
        indexes :month, type: "long"
        indexes :quality_grade, type: "keyword"
      end
      indexes :project_observation_rules, type: :nested do
        indexes :operator, type: "keyword"
        indexes :operand_type, type: "keyword"
      end
      indexes :rule_preferences, type: :nested do
        indexes :field, type: "keyword"
        indexes :value, type: "text"
      end
      indexes :flags do
        indexes :flag, type: "keyword"
      end
      indexes :site_features, type: :nested do
        indexes :site_id
        indexes :noteworthy, type: "boolean"
        indexes :updated_at, type: "date"
      end
    end
  end

  def as_indexed_json(options={})
    preload_for_elastic_index
    obs_result = INatAPIService.observations( per_page: 0, project_id: id )
    {
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
      user_ids: project_users.map(&:user_id).uniq.sort,
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
        select{ |k,v| Project::RULE_PREFERENCES.include?(k) && !v.blank? }.
        map{ |k,v| { field: k.sub("rule_",""), value: v } },
      created_at: created_at,
      updated_at: updated_at,
      last_post_at: posts.published.last.try(:published_at),
      observations_count: obs_result ? obs_result.total_results : nil,
      spam: known_spam? || owned_by_spammer?,
      flags: flags.map(&:as_indexed_json),
      site_features: site_featured_projects.map(&:as_indexed_json)
    }
  end

end
