class Project < ActiveRecord::Base

  include ActsAsElasticModel

  DEFAULT_ES_BATCH_SIZE = 500

  scope :load_for_index, -> { includes(
    :place,
    :project_users,
    :observation_fields,
    :project_observation_rules,
    :stored_preferences
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
      indexes :project_type, analyzer: "keyword_analyzer"
      indexes :location, type: "geo_point"
      indexes :geojson, type: "geo_shape"
      indexes :search_parameters, type: :nested do
        indexes :field, type: "keyword"
        indexes :value, type: "text"
        indexes :value_date, type: "date", format: "dateOptionalTime"
        indexes :value_boolean, type: "boolean"
        indexes :value_number, type: "long"
      end
      indexes :project_observation_rules, type: :nested do
        indexes :operator, type: "keyword"
        indexes :operand_type, type: "keyword"
      end
      indexes :rule_preferences, type: :nested do
        indexes :field, type: "keyword"
      end
    end
  end

  def as_indexed_json(options={})
    preload_for_elastic_index
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
      manager_ids: managers.map(&:id),
      rule_place_ids: rule_place_ids,
      user_ids: project_users.map(&:user_id).sort,
      location: ElasticModel.point_latlon(latitude, longitude),
      geojson: ElasticModel.point_geojson(latitude, longitude),
      icon: icon ? FakeView.asset_url( icon.url(:span2), host: Site.default.url ) : nil,
      header_image_url: cover.blank? ? nil : FakeView.asset_url( cover.url, host: Site.default.url ),
      project_observation_fields: project_observation_fields.uniq.map(&:as_indexed_json),
      search_parameters: search_parameters.map{ |field,value| {
        field: field,
        value: value
      } },
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
      updated_at: updated_at
    }
  end

end
