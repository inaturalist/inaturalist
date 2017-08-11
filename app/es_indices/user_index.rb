class User < ActiveRecord::Base

  include ActsAsElasticModel

  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :icon, type: "keyword", index: false
      indexes :login, analyzer: "ascii_snowball_analyzer"
      indexes :login_autocomplete, analyzer: "autocomplete_analyzer",
        search_analyzer: "standard_analyzer"
      indexes :name, analyzer: "ascii_snowball_analyzer"
      indexes :name_autocomplete, analyzer: "autocomplete_analyzer",
        search_analyzer: "standard_analyzer"
    end
  end

  def as_indexed_json(options={})
    json = {
      id: id,
      login: login
    }
    unless options[:no_details]
      json.merge!({
        login_autocomplete: login,
        name: name,
        name_autocomplete: name,
        icon: icon.file? ? icon.url(:thumb) : nil,
        observations_count: observations_count,
        identifications_count: identifications_count,
        journal_posts_count: journal_posts_count,
        activity_count: observations_count + identifications_count + journal_posts_count,
        roles: roles.map(&:name)
      })
    end
    json
  end

end
