class User < ApplicationRecord
  include ActsAsElasticModel

  scope :load_for_index, -> { includes( :roles, :flags, :provider_authorizations ) }


  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :activity_count, type: "integer"
      indexes :created_at, type: "date"
      indexes :icon, type: "keyword", index: false
      indexes :id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :identifications_count, type: "integer"
      indexes :journal_posts_count, type: "integer"
      indexes :login, analyzer: "ascii_snowball_analyzer"
      indexes :login_autocomplete, analyzer: "autocomplete_analyzer",
        search_analyzer: "standard_analyzer"
      indexes :login_exact, type: "keyword"
      indexes :name, analyzer: "ascii_snowball_analyzer"
      indexes :name_autocomplete, analyzer: "autocomplete_analyzer",
        search_analyzer: "standard_analyzer"
      indexes :observations_count, type: "integer"
      indexes :species_count, type: "integer"
      indexes :orcid, type: "keyword"
      indexes :roles, type: "keyword"
      indexes :site_id, type: "short" do
        indexes :keyword, type: "keyword"
      end
      indexes :spam, type: "boolean"
      indexes :suspended, type: "boolean"
      indexes :universal_search_rank, type: "integer"
      indexes :uuid, type: "keyword"
    end
  end

  def as_indexed_json(options={})
    json = {
      id: id,
      login: login,
      spam: known_spam?,
      suspended: suspended?,
      created_at: created_at.in_time_zone( "UTC" )
    }
    unless options[:no_details]
      obs_count = [observations_count.to_i, 0].max
      ident_count = [identifications_count.to_i, 0].max
      post_count = [journal_posts_count.to_i, 0].max
      json.merge!({
        login_autocomplete: login,
        login_exact: login,
        name: name,
        name_autocomplete: name,
        orcid: orcid,
        icon: icon.file? ? icon.url(:thumb) : nil,
        observations_count: obs_count,
        identifications_count: ident_count,
        journal_posts_count: post_count,
        activity_count: obs_count + ident_count + post_count,
        species_count: species_count,
        universal_search_rank: obs_count,
        roles: roles.map(&:name).uniq,
        site_id: site_id
      })
    end
    json
  end

end
