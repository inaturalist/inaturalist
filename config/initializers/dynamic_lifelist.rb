module DynamicLifelist

  def self.export(user)
    return unless user && user.is_a?( User )
    json = INatAPIService.get( "/observations/lifelist_export?user_id=#{ user.id }" )
    if json.blank?
      return
    end
    fname = "lifelist-#{ user.login }-#{ Time.now.to_i }.csv"
    tmp_path = File.join( Dir::tmpdir, fname )
    FileUtils.mkdir_p( File.dirname( tmp_path ), mode: 0755 )
    headers = [
      "id",
      "parent_id",
      "name",
      "common_name",
      "rank",
      "is_leaf",
      "observation_count",
      "leaf_count",
      "first_observed",
      "last_observed",
      "first_observation",
      "last_observation"
    ]
    CSV.open( tmp_path, "w" ) do |csv|
      csv << headers
      json.results.each do |taxon|
        csv << [
          taxon["id"],
          taxon["parent_id"],
          taxon["name"],
          taxon["preferred_common_name"],
          taxon["rank"],
          taxon["is_leaf"],
          taxon["observation_count"],
          taxon["leaf_count"],
          taxon["earliest_observation"]["observed_on"],
          taxon["latest_observation"]["observed_on"],
          UrlHelper.observation_url( taxon["earliest_observation"]["id"] ),
          UrlHelper.observation_url( taxon["latest_observation"]["id"] ),
        ]
      end
    end
    return tmp_path
  end

end
