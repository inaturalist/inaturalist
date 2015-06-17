class Observation < ActiveRecord::Base

  include ActsAsElasticModel

  attr_accessor :indexed_tag_names
  attr_accessor :indexed_project_ids
  attr_accessor :indexed_place_ids

  scope :load_for_index, -> { includes(:user,
    { sounds: :user },
    { photos: :user },
    { taxon: [ :taxon_names ] },
    { observation_field_values: :observation_field } ) }
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :id, type: "integer"
      indexes :taxon do
        indexes :names do
          indexes :name, analyzer: "ascii_snowball_analyzer"
        end
      end
      indexes :photos do
        indexes :license_code, analyzer: "keyword_analyzer"
      end
      indexes :sounds do
        indexes :license_code, analyzer: "keyword_analyzer"
      end
      indexes :field_values do
        indexes :name, analyzer: "keyword_analyzer"
        indexes :value, analyzer: "keyword_analyzer"
      end
      indexes :description, analyzer: "ascii_snowball_analyzer"
      indexes :tags, analyzer: "ascii_snowball_analyzer"
      indexes :place_guess, analyzer: "ascii_snowball_analyzer"
      indexes :species_guess, analyzer: "keyword_analyzer"
      indexes :license_code, analyzer: "keyword_analyzer"
      indexes :observed_on, type: "date", format: "dateOptionalTime"
      indexes :observed_on_string, type: "string"
      indexes :location, type: "geo_point", lat_lon: true, geohash: true, geohash_precision: 10
      indexes :private_location, type: "geo_point", lat_lon: true
      indexes :geojson, type: "geo_shape"
      indexes :private_geojson, type: "geo_shape"
    end
  end

  def as_indexed_json(options={})
    preload_for_elastic_index
    {
      id: id,
      created_at: created_at ? created_at.utc : nil,
      created_at_details: created_at ? ElasticModel.date_details(created_at.utc) : nil,
      updated_at: updated_at ? updated_at.utc : nil,
      observed_on: datetime ? datetime.utc : nil,
      observed_on_details: datetime ? ElasticModel.date_details(datetime.utc) : nil,
      time_observed_at: time_observed_at ? time_observed_at.utc : nil,
      site_id: site_id,
      uri: uri,
      description: description,
      mappable: mappable,
      species_guess: species_guess.blank? ? nil : species_guess,
      place_guess: place_guess.blank? ? nil : place_guess,
      observed_on_string: observed_on_string,
      quality_grade: quality_grade,
      id_please: id_please,
      out_of_range: out_of_range,
      captive: captive,
      license_code: license,
      geoprivacy: geoprivacy,
      cached_votes_total: cached_votes_total,
      num_identification_agreements: num_identification_agreements,
      num_identification_disagreements: num_identification_disagreements,
      identifications_most_agree:
        (num_identification_agreements > num_identification_disagreements),
      identifications_some_agree:
        (num_identification_agreements > 0),
      identifications_most_disagree:
        (num_identification_agreements < num_identification_disagreements),
      place_ids: (indexed_place_ids || observations_places.map(&:place_id)).compact.uniq,
      project_ids: (indexed_project_ids || project_observations.map(&:project_id)).compact.uniq,
      tags: (indexed_tag_names || tags.map(&:name)).compact.uniq,
      user: user ? user.as_indexed_json : nil,
      taxon: taxon ? taxon.as_indexed_json(basic: true) : nil,
      field_values: observation_field_values.uniq.map(&:as_indexed_json),
      photos: photos.map(&:as_indexed_json),
      sounds: sounds.map(&:as_indexed_json),
      location: (latitude && longitude) ?
        ElasticModel.point_latlon(latitude, longitude) : nil,
      private_location: (private_latitude && private_longitude) ?
        ElasticModel.point_latlon(private_latitude, private_longitude) : nil,
      geojson: ElasticModel.geom_geojson(geom),
      private_geojson: ElasticModel.geom_geojson(private_geom)
    }
  end

  # to quickly fetch tag names and project_ids when bulk indexing
  def self.prepare_batch_for_index(observations)
    # make sure we default all caches to empty arrays
    # this prevents future lookups for instances with no results
    observations.each{ |o|
      o.indexed_tag_names ||= [ ]
      o.indexed_project_ids ||= [ ]
      o.indexed_place_ids ||= [ ]
    }
    observations_by_id = Hash[ observations.map{ |o| [ o.id, o ] } ]
    batch_ids_string = observations_by_id.keys.join(",")
    # fetch all tag names store them in `indexed_tag_names`
    connection.execute("
      SELECT ts.taggable_id, t.name
      FROM taggings ts
      JOIN tags t ON (ts.tag_id = t.id)
      WHERE ts.taggable_type='Observation' AND
      ts.taggable_id IN (#{ batch_ids_string })").to_a.each do |r|
      if o = observations_by_id[ r["taggable_id"].to_i ]
        o.indexed_tag_names << r["name"]
      end
    end
    # fetch all project_ids store them in `indexed_project_ids`
    connection.execute("
      SELECT observation_id, project_id
      FROM project_observations
      WHERE observation_id IN (#{ batch_ids_string })").to_a.each do |r|
      if o = observations_by_id[ r["observation_id"].to_i ]
        o.indexed_project_ids << r["project_id"].to_i
      end
    end
    # fetch all place_ids store them in `indexed_place_ids`
    connection.execute("
      SELECT observation_id, place_id
      FROM observations_places
      WHERE observation_id IN (#{ batch_ids_string })").to_a.each do |r|
      if o = observations_by_id[ r["observation_id"].to_i ]
        o.indexed_place_ids << r["place_id"].to_i
      end
    end
  end

  def self.params_to_elastic_query(params, options = {})
    current_user = options[:current_user]
    p = params[:_query_params_set] ? params : query_params(params)
    if (Observation::NON_ELASTIC_ATTRIBUTES & p.reject{ |k,v| v.blank? || v == "any" }.keys).any?
      return nil
    end
    p = site_search_params(options[:site], p)
    search_wheres = { }
    extra_preloads = [ ]
    q = unless p[:q].blank?
      q = sanitize_query(p[:q])
      q.blank? ? nil : q
    end
    search_on = p[:search_on] if Observation::FIELDS_TO_SEARCH_ON.include?(p[:search_on])
    if q
      fields = case search_on
      when "names"
        [ "taxon.names.name" ]
      when "tags"
        [ :tags ]
      when "description"
        [ :description ]
      when "place"
        [ :place_guess ]
      else
        [ "taxon.names.name", :tags, :description, :place_guess ]
      end
      search_wheres["multi_match"] = { query: q, operator: "and", fields: fields }
    end
    search_wheres["user.id"] = p[:user] if p[:user]
    search_wheres["taxon.rank"] = p[:rank] if p[:rank]
    # include the taxon plus all of its descendants.
    # Every taxon has its own ID in ancestor_ids
    if p[:observations_taxon]
      search_wheres["taxon.ancestor_ids"] = p[:observations_taxon]
    elsif p[:observations_taxon_ids]
      search_wheres["taxon.ancestor_ids"] = p[:observations_taxon_ids]
    end
    search_wheres["id_please"] = true if p[:id_please]
    search_wheres["out_of_range"] = true if p[:out_of_range]
    search_wheres["mappable"] = true if p[:mappable] == "true"
    search_wheres["mappable"] = false if p[:mappable] == "false"
    search_wheres["license_code"] = p[:license] if p[:license]
    search_wheres["photos.license_code"] = p[:photo_license] if p[:photo_license]
    search_wheres["sounds.license_code"] = p[:sound_license] if p[:sound_license]
    search_wheres["observed_on_details.day"] = p[:observed_on_day] if p[:observed_on_day]
    search_wheres["observed_on_details.month"] = p[:observed_on_month] if p[:observed_on_month]
    search_wheres["observed_on_details.year"] = p[:observed_on_year] if p[:observed_on_year]
    if d = Observation.split_date(p[:created_on], utc: true)
      search_wheres["created_at_details.day"] = d[:day] if d[:day] && d[:day] != 0
      search_wheres["created_at_details.month"] = d[:month] if d[:month] && d[:month] != 0
      search_wheres["created_at_details.year"] = d[:year] if d[:year] && d[:day] != 0
    end
    if p[:projects].blank? && !p[:project].blank?
      p[:projects] = [ p[:project] ]
    end
    extra = p[:extra].to_s.split(',')
    if !p[:projects].blank?
      search_wheres["project_ids"] = p[:projects].to_a
      extra_preloads << :projects
    end
    extra_preloads << {identifications: [:user, :taxon]} if extra.include?('identifications')
    extra_preloads << {observation_photos: :photo} if extra.include?('observation_photos')
    extra_preloads << {observation_field_values: :observation_field} if extra.include?('fields')
    unless p[:hrank].blank? && p[:lrank].blank?
      search_wheres["range"] = { "taxon.rank_level" => {
        from: Taxon::RANK_LEVELS[p[:lrank]] || 0,
        to: Taxon::RANK_LEVELS[p[:hrank]] || 100 } }
    end
    if p[:captive].is_a?(FalseClass) || p[:captive].is_a?(TrueClass)
      search_wheres["captive"] = p[:captive]
    end
    if p[:quality_grade] && p[:quality_grade] != "any"
      search_wheres["quality_grade"] = p[:quality_grade]
    end
    case p[:identifications]
    when "most_agree"
      search_wheres["identifications_most_agree"] = true
    when "some_agree"
      search_wheres["identifications_some_agree"] = true
    when "most_disagree"
      search_wheres["identifications_most_disagree"] = true
    end

    search_filters = []
    unless p[:nelat].blank? && p[:nelng].blank? && p[:swlat].blank? && p[:swlng].blank?
      search_filters << { envelope: { geojson: {
        nelat: p[:nelat], nelng: p[:nelng], swlat: p[:swlat], swlng: p[:swlng],
        user: current_user } } }
    end
    if p[:lat] && p[:lng]
      search_filters << { geo_distance: {
        distance: "#{p["radius"] || 10}km",
        location: {
          lat: p[:lat], lon: p[:lng] } } }
    end
    search_wheres[:place_ids] = p[:place] if p[:place]
    # make sure the photo has a URL, that will prevent images that are
    # still processing from being returned by has[]=photos requests
    search_filters << { exists: { field: "photos.url" } } if p[:with_photos]
    search_filters << { exists: { field: "sounds" } } if p[:with_sounds]
    search_filters << { exists: { field: "geojson" } } if p[:with_geo]
    if p[:iconic_taxa] && p[:iconic_taxa].size > 0
      # iconic_taxa will be an array which might contain a nil value
      known_taxa = p[:iconic_taxa].compact
      # if it is smaller after compact, then it contained nil and
      # we will need to do a different kind of Elasticsearch query
      allows_unknown = (known_taxa.size < p[:iconic_taxa].size)
      if allows_unknown
        # to allow iconic_taxon_id to be nil, I think the best way
        # is a "should" boolean filter, which allows anyof a set of
        # valid terms as well as missing terms (null)
        search_filters << { bool: { should: [
          { terms: { "taxon.iconic_taxon_id": known_taxa.map(&:id) } },
          { missing: { field: "taxon.iconic_taxon_id" } }
        ]}}
      else
        # if we don't want to include null values, a where clause is simpler
        search_wheres["taxon.iconic_taxon_id"] = p[:iconic_taxa]
      end
    end
    if p[:d1] || p[:d2]
      p[:d2] = Time.now if p[:d2] && p[:d2] > Time.now
      search_filters << { or: [
        { and: [
          { range: { observed_on: {
            gte: p[:d1] || Time.new("1800"), lte: p[:d2] || Time.now } } },
          { exists: { field: "time_observed_at" } }
        ] },
        { and: [
          { range: { observed_on: {
            gte: (p[:d1] || Time.new("1800")).to_date, lte: (p[:d2] || Time.now).to_date } } },
          { missing: { field: "time_observed_at" } }
        ] }
      ] }
    end
    unless p[:updated_since].blank?
      if timestamp = Chronic.parse(p[:updated_since])
        search_filters << { range: { updated_at: { gte: timestamp } } }
      else
        # there is an expectation in a spec that when updated_since is
        # invalid, the search will fail to return any results
        return nil
      end
    end
    # sort defaults to created at descending
    sort_order = (p[:order] || "desc").downcase.to_sym
    sort = case p[:order_by]
    when "observed_on"
      { observed_on: sort_order }
    when "species_guess"
      { species_guess: sort_order }
    when "votes"
      { cached_votes_total: sort_order }
    else "observations.id"
      { created_at: sort_order }
    end

    if p[:not_in_project]
      project_id = p[:not_in_project].is_a?(Project) ? p[:not_in_project].id : p[:not_in_project]
      search_filters << {
        'not': {
          term: { project_ids: project_id }
        }
      }
    end

    if p[:identified].yesish?
      search_filters << { exists: {field: :taxon} }
    elsif p[:identified].noish?
      search_filters << { 'not': { exists: {field: :taxon} } }
    end

    { where: search_wheres,
      filters: search_filters,
      per_page: p[:per_page] || 30,
      page: p[:page],
      sort: sort,
      extra_preloads: extra_preloads }
  end

end
