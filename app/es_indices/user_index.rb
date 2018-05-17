class User < ActiveRecord::Base
  include ActsAsElasticModel

  scope :load_for_index, -> { includes( :roles, :flags ) }


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
      login: login,
      spam: known_spam?,
      suspended: suspended?
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
        icon: icon.file? ? icon.url(:thumb) : nil,
        observations_count: obs_count,
        identifications_count: ident_count,
        journal_posts_count: post_count,
        activity_count: obs_count + ident_count + post_count,
        roles: roles.map(&:name),
        site_id: site_id
      })
    end
    json
  end

end
