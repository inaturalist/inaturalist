class Observation < ActiveRecord::Base

  include ActsAsElasticModel

  DEFAULT_ES_BATCH_SIZE = 500

  attr_accessor :indexed_tag_names, :indexed_project_ids, :indexed_place_ids,
    :indexed_places, :indexed_project_ids_with_curator_id,
    :indexed_project_ids_without_curator_id

  scope :load_for_index, -> { includes(
    :user, :confirmed_reviews, :flags,
    :model_attribute_changes,
    :votes_for,
    { annotations: :votes_for },
    { project_observations_with_changes: :model_attribute_changes },
    { sounds: :user },
    { photos: [ :user, :flags ] },
    { taxon: [ { taxon_names: :place_taxon_names }, :conservation_statuses,
      { listed_taxa_with_establishment_means: :place } ] },
    { observation_field_values: :observation_field },
    { identifications: [ :user, :taxon ] },
    { comments: :user } ) }
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :id, type: "integer"
      indexes :uuid, analyzer: "keyword_analyzer"
      indexes :taxon do
        indexes :names do
          indexes :name, analyzer: "ascii_snowball_analyzer"
        end
        indexes :statuses, type: :nested do
          indexes :authority, analyzer: "keyword_analyzer"
          indexes :status, analyzer: "keyword_analyzer"
        end
      end
      indexes :photos do
        indexes :license_code, analyzer: "keyword_analyzer"
      end
      indexes :sounds do
        indexes :license_code, analyzer: "keyword_analyzer"
      end
      indexes :ofvs, type: :nested do
        indexes :uuid, analyzer: "keyword_analyzer"
        indexes :name, analyzer: "keyword_analyzer"
        indexes :value, analyzer: "keyword_analyzer"
        indexes :datatype, analyzer: "keyword_analyzer"
      end
      indexes :annotations, type: :nested do
        indexes :uuid, analyzer: "keyword_analyzer"
        indexes :resource_type, analyzer: "keyword_analyzer"
        indexes :concatenated_attr_val, analyzer: "keyword_analyzer"
      end
      indexes :non_owner_ids, type: :nested do
        indexes :uuid, analyzer: "keyword_analyzer"
      end
      indexes :field_change_times, type: :nested do
      end
      indexes :comments do
        indexes :uuid, analyzer: "keyword_analyzer"
        indexes :body, analyzer: "ascii_snowball_analyzer"
      end
      indexes :project_observations do
        indexes :uuid, analyzer: "keyword_analyzer"
      end
      indexes :observation_photos do
        indexes :uuid, analyzer: "keyword_analyzer"
      end
      indexes :votes, type: :nested do
        indexes :vote_scope, analyzer: "keyword_analyzer"
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
    preload_for_elastic_index unless options[:no_details]
    # some timezones are invalid
    created = created_at.in_time_zone(timezone_object || "UTC")
    t = taxon || community_taxon
    json = {
        id: id,
        uuid: uuid,
        site_id: site_id,
        created_at: created,
        created_at_details: ElasticModel.date_details(created),
        observed_on: datetime.blank? ? nil : datetime.to_date,
        observed_on_details: ElasticModel.date_details(datetime),
        time_observed_at: time_observed_at_in_zone,
        place_ids: (indexed_place_ids || observations_places.map(&:place_id)).compact.uniq,
        quality_grade: quality_grade,
        captive: captive,
        user: user ? user.as_indexed_json(no_details: true) : nil,
        taxon: t ? t.as_indexed_json(for_observation: true,
          no_details: options[:no_details],
          for_identification: options[:for_identification]) : nil
    }

    unless options[:no_details]
      json.merge!({
        created_time_zone: timezone_object.blank? ? "UTC" : timezone_object.tzinfo.name,
        updated_at: updated_at.in_time_zone(timezone_object || "UTC"),
        observed_time_zone: timezone_object.blank? ? nil : timezone_object.tzinfo.name,
        time_zone_offset: timezone_offset,
        uri: uri,
        description: description,
        mappable: mappable,
        species_guess: species_guess.blank? ? nil : species_guess,
        place_guess: place_guess.blank? ? nil : place_guess,
        observed_on_string: observed_on_string,
        id_please: id_please,
        out_of_range: out_of_range,
        license_code: license ? license.downcase : nil,
        geoprivacy: geoprivacy,
        faves_count: cached_votes_total,
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
        project_ids: (indexed_project_ids || project_observations).map{ |po| po[:project_id] }.compact.uniq,
        project_ids_with_curator_id: (indexed_project_ids_with_curator_id ||
          project_observations.select{ |po| !po.curator_identification_id.nil? }.
            map(&:project_id)).compact.uniq,
        project_ids_without_curator_id: (indexed_project_ids_without_curator_id ||
          project_observations.select{ |po| po.curator_identification_id.nil? }.
            map(&:project_id)).compact.uniq,
        project_observations: (indexed_project_ids || project_observations).map{ |po|
          { project_id: po[:project_id], user_id: po[:user_id], uuid: po[:uuid] } },
        reviewed_by: confirmed_reviews.map(&:user_id),
        tags: (indexed_tag_names || tags.map(&:name)).compact.uniq,
        ofvs: observation_field_values.uniq.map(&:as_indexed_json),
        annotations: annotations.map(&:as_indexed_json),
        photos: observation_photos.sort_by{ |op| op.position || op.id }.
          reject{ |op| op.photo.blank? }.
          map{ |op| op.photo.as_indexed_json },
        observation_photos: observation_photos.sort_by{ |op| op.position || op.id }.
          reject{ |op| op.photo.blank? }.
          each_with_index.map{ |op, i|
            { uuid: op.uuid, photo_id: op.photo.id, position: i }
        },
        sounds: sounds.map(&:as_indexed_json),
        non_owner_ids: others_identifications.map{ |i| i.as_indexed_json(no_details: true) },
        identifications_count: num_identifications_by_others,
        comments: comments.map(&:as_indexed_json),
        comments_count: comments.size,
        obscured: coordinates_obscured? || geoprivacy_obscured?,
        field_change_times: field_changes_to_index,
        positional_accuracy: positional_accuracy,
        location: (latitude && longitude) ?
          ElasticModel.point_latlon(latitude, longitude) : nil,
        private_location: (private_latitude && private_longitude) ?
          ElasticModel.point_latlon(private_latitude, private_longitude) : nil,
        geojson: (latitude && longitude) ?
          ElasticModel.point_geojson(latitude, longitude) : nil,
        private_geojson: (private_latitude && private_longitude) ?
          ElasticModel.point_geojson(private_latitude, private_longitude) : nil,
        votes: votes_for.map{ |v|
          { user_id: v.voter_id, vote_flag: v.vote_flag, vote_scope: v.vote_scope }
        }
      })
      add_taxon_statuses(json, t) if t && json[:taxon]
    end
    json
  end

  # to quickly fetch tag names and project_ids when bulk indexing
  def self.prepare_batch_for_index(observations, options = {})
    # make sure we default all caches to empty arrays
    # this prevents future lookups for instances with no results
    observations.each{ |o|
      o.indexed_tag_names ||= [ ]
      o.indexed_project_ids ||= [ ]
      o.indexed_project_ids_with_curator_id ||= [ ]
      o.indexed_project_ids_without_curator_id ||= [ ]
      o.indexed_project_ids_with_curator_id ||= [ ]
      o.indexed_place_ids ||= [ ]
      o.indexed_places ||= [ ]
    }
    observations_by_id = Hash[ observations.map{ |o| [ o.id, o ] } ]
    batch_ids_string = observations_by_id.keys.join(",")
    if options.blank? || options[:tags]
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
    end
    # fetch all project_ids store them in `indexed_project_ids`
    if options.blank? || options[:projects]
      connection.execute("
        SELECT observation_id, project_id, curator_identification_id, uuid, user_id
        FROM project_observations
        WHERE observation_id IN (#{ batch_ids_string })").to_a.each do |r|
        if o = observations_by_id[ r["observation_id"].to_i ]
          o.indexed_project_ids << { project_id: r["project_id"].to_i,
            uuid: r["uuid"], user_id: r["user_id"] }
          # these are for the `pcid` search param
          if r["curator_identification_id"].nil?
            o.indexed_project_ids_without_curator_id << r["project_id"].to_i
          else
            o.indexed_project_ids_with_curator_id << r["project_id"].to_i
          end
        end
      end
    end
    # fetch all place_ids store them in `indexed_place_ids`
    if options.blank? || options[:places]
      connection.execute("
        SELECT observation_id, place_id
        FROM observations_places
        WHERE observation_id IN (#{ batch_ids_string })").to_a.each do |r|
        if o = observations_by_id[ r["observation_id"].to_i ]
          o.indexed_place_ids << r["place_id"].to_i
        end
      end
      place_ids = observations.map(&:indexed_place_ids).flatten.uniq.compact
      places_by_id = Hash[ Place.where(id: place_ids).map{ |p| [ p.id, p ] } ]
      observations.each do |o|
        unless o.indexed_place_ids.blank?
          o.indexed_places = places_by_id.values_at(*o.indexed_place_ids).compact
        end
      end
    end
  end

  def self.params_to_elastic_query(params, options = {})
    current_user = options[:current_user] || params[:viewer]
    p = params[:_query_params_set] ? params : query_params(params)
    return nil unless Observation.able_to_use_elasticsearch?(p)
    # one of the param initializing steps saw an impossible condition
    return nil if p[:empty_set]
    p = site_search_params(options[:site], p)
    search_wheres = { }
    complex_wheres = [ ]
    search_filters = [ ]
    extra_preloads = [ ]
    q = p[:q] unless p[:q].blank?
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
    if p[:user]
      search_filters << { term: {
        "user.id" => ElasticModel.id_or_object(p[:user]) } }
    elsif p[:user_id]
      search_filters << { terms: {
        "user.id" => [ p[:user_id] ].flatten.map{ |u| ElasticModel.id_or_object(u) } } }
    end

    # params to search based on value
    [ { http_param: :rank, es_field: "taxon.rank" },
      { http_param: :sound_license, es_field: "sounds.license_code" },
      { http_param: :observed_on_day, es_field: "observed_on_details.day" },
      { http_param: :observed_on_month, es_field: "observed_on_details.month" },
      { http_param: :observed_on_year, es_field: "observed_on_details.year" },
      { http_param: :day, es_field: "observed_on_details.day" },
      { http_param: :month, es_field: "observed_on_details.month" },
      { http_param: :year, es_field: "observed_on_details.year" },
      { http_param: :week, es_field: "observed_on_details.week" },
      { http_param: :place_id, es_field: "place_ids" },
      { http_param: :site_id, es_field: "site_id" },
      { http_param: :id, es_field: "id" }
    ].each do |filter|
      unless p[ filter[:http_param] ].blank? || p[ filter[:http_param] ] == "any"
        search_filters << { terms: { filter[:es_field] =>
          [ p[ filter[:http_param] ] ].flatten.map{ |v|
            ElasticModel.id_or_object(v) } } }
      end
    end

    # params that can be true / false / any
    [ { http_param: :introduced, es_field: "taxon.introduced" },
      { http_param: :threatened, es_field: "taxon.threatened" },
      { http_param: :native, es_field: "taxon.native" },
      { http_param: :endemic, es_field: "taxon.endemic" },
      { http_param: :id_please, es_field: "id_please" },
      { http_param: :out_of_range, es_field: "out_of_range" },
      { http_param: :mappable, es_field: "mappable" },
      { http_param: :captive, es_field: "captive" }
    ].each do |filter|
      if p[ filter[:http_param] ].yesish?
        search_filters << { term: { filter[:es_field] => true } }
      elsif p[ filter[:http_param] ].noish?
        search_filters << { term: { filter[:es_field] => false } }
      end
    end

    # params that can check for presence of something
    [ { http_param: :with_photos, es_field: "photos.url" },
      { http_param: :with_sounds, es_field: "sounds" },
      { http_param: :with_geo, es_field: "geojson" },
      { http_param: :identified, es_field: "taxon" },
    ].each do |filter|
      f = { exists: { field: filter[:es_field] } }
      if p[ filter[:http_param] ].yesish?
        search_filters << f
      elsif p[ filter[:http_param] ].noish?
        search_filters << { not: f }
      end
    end
    if p[:verifiable].yesish?
      search_filters << { terms: {
        quality_grade: [ "research", "needs_id" ] } }
    elsif p[:verifiable].noish?
      search_filters << { not: { terms: {
        quality_grade: [ "research", "needs_id" ] } } }
    end
    # include the taxon plus all of its descendants.
    # Every taxon has its own ID in ancestor_ids
    if p[:observations_taxon]
      search_filters << { term: {
        "taxon.ancestor_ids" => ElasticModel.id_or_object(p[:observations_taxon]) } }
    elsif p[:observations_taxon_ids]
      search_filters << { terms: {
        "taxon.ancestor_ids" => p[:observations_taxon_ids] } }
    end
    if p[:license] == "any"
      search_filters << { exists: { field: "license_code" } }
    elsif p[:license] == "none"
      search_filters << { missing: { field: "license_code" } }
    elsif p[:license]
      search_filters << { terms: { license_code:
        [ p[:license] ].flatten.map{ |l| l.downcase } } }
    end
    if p[:photo_license] == "any"
      search_filters << { exists: { field: "photos.license_code" } }
    elsif p[:photo_license] == "none"
      search_filters << { missing: { field: "photos.license_code" } }
    elsif p[:photo_license]
      search_filters << { terms: { "photos.license_code" =>
        [ p[:photo_license] ].flatten.map{ |l| l.downcase } } }
    end
    if d = Observation.split_date(p[:created_on], utc: true)
      [ :day, :month, :year ].each do |part|
        if d[part] && d[part] != 0
          search_filters << { term: { "created_at_details.#{ part }" => d[part] } }
        end
      end
    end
    if p[:projects].blank? && !p[:project].blank?
      p[:projects] = [ p[:project] ]
    end
    p[:projects] = [p[:projects]].flatten if p[:projects]
    extra = p[:extra].to_s.split(",")
    if !p[:projects].blank?
      project_ids = p[:projects].map{ |proj| ElasticModel.id_or_object(proj) }
      search_filters << { terms: { project_ids: project_ids } }
      extra_preloads << :projects
      # since we have projects, check the `pcid` param
      if params[:pcid].yesish?
        search_filters << { terms: {
          project_ids_with_curator_id: project_ids } }
      elsif params[:pcid].noish?
        search_filters << { terms: {
          project_ids_without_curator_id: project_ids } }
      end
    else
      if params[:pcid].yesish?
        search_filters << { exists: {
          field: "project_ids_with_curator_id" } }
      elsif params[:pcid].noish?
        search_filters << { exists: {
          field: "project_ids_without_curator_id" } }
      end
    end
    if p[:not_in_project]
      search_filters << { not: { term: { project_ids:
        ElasticModel.id_or_object(p[:not_in_project]) } } }
    end

    extra_preloads << { identifications: [:user, :taxon] } if extra.include?("identifications")
    extra_preloads << { observation_photos: :photo } if extra.include?("observation_photos")
    extra_preloads << { observation_field_values: :observation_field } if extra.include?("fields")
    unless p[:hrank].blank? && p[:lrank].blank?
      search_filters << { range: { "taxon.rank_level" => {
        gte: Taxon::RANK_LEVELS[p[:lrank]] || 0,
        lte: Taxon::RANK_LEVELS[p[:hrank]] || 100 } } }
    end
    if p[:quality_grade] && p[:quality_grade] != "any"
      search_filters << { terms: { quality_grade:
        p[:quality_grade].to_s.split(",") & Observation::QUALITY_GRADES } }
    end
    case p[:identifications]
    when "most_agree"
      search_filters << { term: { identifications_most_agree: true } }
    when "some_agree"
      search_filters << { term: { identifications_some_agree: true } }
    when "most_disagree"
      search_filters << { term: { identifications_most_disagree: true } }
    end

    unless p[:nelat].blank? && p[:nelng].blank? && p[:swlat].blank? && p[:swlng].blank?
      search_filters << { envelope: { geojson: {
        nelat: p[:nelat], nelng: p[:nelng], swlat: p[:swlat], swlng: p[:swlng],
        user: current_user } } }
    end
    if p[:lat] && p[:lng]
      search_filters << { geo_distance: {
        distance: "#{p[:radius] || 10}km",
        location: {
          lat: p[:lat], lon: p[:lng] } } }
    end
    if p[:iconic_taxa_instances] && p[:iconic_taxa_instances].size > 0
      # iconic_taxa will be an array which might contain a nil value
      known_taxa = p[:iconic_taxa_instances].compact
      # if it is smaller after compact, then it contained nil and
      # we will need to do a different kind of Elasticsearch query
      allows_unknown = (known_taxa.size < p[:iconic_taxa_instances].size)
      if allows_unknown
        # to allow iconic_taxon_id to be nil, I think the best way
        # is a "should" boolean filter, which allows anyof a set of
        # valid terms as well as missing terms (null)
        search_filters << { bool: { should: [
          { terms: { "taxon.iconic_taxon_id" => known_taxa.map(&:id) } },
          { missing: { field: "taxon.iconic_taxon_id" } }
        ]}}
      else
        # if we don't want to include null values, a terms filter is simpler
        search_filters << { terms: { "taxon.iconic_taxon_id" =>
          p[:iconic_taxa_instances].map{ |t| ElasticModel.id_or_object(t) } } }
      end
    end

    if current_user
      if p[:reviewed].yesish?
        search_filters << { term: { reviewed_by: current_user.id } }
      elsif p[:reviewed].noish?
        search_filters << { not: { term: { reviewed_by: current_user.id } } }
      end
    end

    if p[:d1] || p[:d2]
      d1 = DateTime.parse(p[:d1]) rescue DateTime.parse("1800-01-01")
      d2 = DateTime.parse(p[:d2]) rescue Time.now
      d2 = Time.now if d2 && d2 > Time.now
      query_by_date = (
        (p[:d1] && d1.to_s =~ /00:00:00/ && p[:d1] !~ /00:00:00/) ||
        (p[:d2] && d2.to_s =~ /00:00:00/ && p[:d2] !~ /00:00:00/))
      date_filter = { "observed_on_details.date": {
        gte: d1.strftime("%F"),
        lte: d2.strftime("%F") }}
      if query_by_date
        search_filters << { range: date_filter }
      else
        time_filter = { time_observed_at: {
          gte: d1.strftime("%FT%T%:z"),
          lte: d2.strftime("%FT%T%:z") } }
        search_filters << { or: [
          { and: [ { range: time_filter }, { exists: { field: "time_observed_at" } } ] },
          { and: [ { range: date_filter }, { missing: { field: "time_observed_at" } } ] }
        ] }
      end
    end
    if p[:h1] && p[:h2]
      p[:h1] = p[:h1].to_i % 24
      p[:h2] = p[:h2].to_i % 24
      if p[:h1] > p[:h2]
        search_filters << { bool: { should: [
          { range: { "observed_on_details.hour" => { gte: p[:h1] } } },
          { range: { "observed_on_details.hour" => { lte: p[:h2] } } }
        ] } }
      else
        search_filters << { range: { "observed_on_details.hour" => {
          gte: p[:h1], lte: p[:h2] } } }
      end
    end
    if p[:m1] && p[:m2]
      p[:m1] = p[:m1].to_i % 12
      p[:m2] = p[:m2].to_i % 12
      if p[:m1] > p[:m2]
        search_filters << { bool: { should: [
          { range: { "observed_on_details.month" => { gte: p[:m1] } } },
          { range: { "observed_on_details.month" => { lte: p[:m2] } } }
        ] } }
      else
        search_filters << { range: { "observed_on_details.month" => {
          gte: p[:m1], lte: p[:m2] } } }
      end
    end
    unless p[:updated_since].blank?
      # This inanity brought to by the fact that all +'s in URLs get interpreted
      # as spaces, so if you want a plus, we either have to handle it like this
      # or you use %2B
      if p[:updated_since].is_a?( String )
        p[:updated_since] = p[:updated_since].gsub( /\s(\d+\:\d+)$/, "+\\1" )
      end
      timestamp = Chronic.parse(p[:updated_since])
      # there is an expectation in a spec that when updated_since is
      # invalid, the search will fail to return any results
      return nil if timestamp.blank?
      if p[:aggregation_user_ids].blank?
        search_filters << { range: { updated_at: { gte: timestamp } } }
      else
        search_filters << { bool: { should: [
          { range: { updated_at: { gte: timestamp } } },
          { terms: { "user.id" => p[:aggregation_user_ids] } }
        ] } }
      end
    end

    if p[:term_id]
      nested_query = {
        nested: {
          path: "annotations",
          query: { bool: { must: [
            { term: { "annotations.controlled_attribute_id": p[:term_id] } },
            { range: { "annotations.vote_score": { gte: 0 } } }
          ] }
          }
        }
      }
      if p[:term_value_id]
        nested_query[:nested][:query][:bool][:must] <<
          { term: { "annotations.controlled_value_id": p[:term_value_id] } }
      end
      complex_wheres << nested_query
    end

    if p[:ofv_params]
      p[:ofv_params].each do |k,v|
        # use a nested query to search within a single nested
        # object and not across all nested objects
        nested_query = {
          nested: {
            path: "ofvs",
            query: { bool: { must: [ { match: {
              "ofvs.name" => v[:observation_field].name } } ] }
            }
          }
        }
        unless v[:value].blank?
          nested_query[:nested][:query][:bool][:must] <<
            { match: { "ofvs.value" => v[:value] } }
        end
        complex_wheres << nested_query
      end
    end
    # conservation status
    unless p[:cs].blank?
      values = [ p[:cs] ].flatten.map(&:downcase)
      complex_wheres << conservation_condition(:status, values, p)
    end
    # IUCN conservation status
    unless p[:csi].blank?
      iucn_equivs = [ p[:csi] ].flatten.map{ |v|
        Taxon::IUCN_CODE_VALUES[v.upcase] }.compact.uniq
      unless iucn_equivs.blank?
        complex_wheres << conservation_condition(:iucn, iucn_equivs, p)
      end
    end
    # conservation status authority
    unless p[:csa].blank?
      values = [ p[:csa] ].flatten.map(&:downcase)
      complex_wheres << conservation_condition(:authority, values, p)
    end
    # sort defaults to created at descending
    sort_order = (p[:order] || "desc").downcase.to_sym
    sort = case p[:order_by]
    when "observed_on"
      { observed_on: sort_order, time_observed_at: sort_order }
    when "species_guess"
      { species_guess: sort_order }
    when "votes"
      { cached_votes_total: sort_order }
    when "id", "observations.id"
      { id: sort_order }
    else
      { created_at: sort_order }
    end

    unless p[:geoprivacy].blank? || p[:geoprivacy] == "any"
      case p[:geoprivacy]
      when Observation::OPEN
        search_filters << { not: { exists: { field: :geoprivacy } } }
      when "obscured_private"
        search_filters << { terms: { geoprivacy: Observation::GEOPRIVACIES } }
      else
        search_filters << { term: { geoprivacy: p[:geoprivacy] } }
      end
    end

    if p[:changed_since]
      if changedDate = DateTime.parse(p[:changed_since])
        nested_query = {
          nested: {
            path: "field_change_times",
            query: { filtered: { query: {
              bool: {
                must: [ { range: { "field_change_times.changed_at":
                  { gte: changedDate.strftime("%F") }}}]
              }
            }}}
          }
        }
        if p[:changed_fields]
          # one of these fields must have changed (and have that recorded by Rails)
          nested_query[:nested][:query][:filtered][:query][:bool][:must] << {
            terms: { "field_change_times.field_name": p[:changed_fields].split(",") }
          }
        end
        if p[:change_project_id]
          # project curator ID must have changed for these projects
          nested_query[:nested][:query][:filtered][:query][:bool][:must] << {
            or: [
              { terms: { "field_change_times.project_id": p[:change_project_id].split(",") } },
              { not: { exists: { field: "field_change_times.project_id" } } }
            ]
          }
        end
        complex_wheres << nested_query
      end
    end

    if p[:popular].yesish?
      search_filters << { range: { cached_votes_total: { gte: 1 } } }
    elsif p[:popular].noish?
      search_filters << { term: { cached_votes_total: 0 } }
    end
    if p[:min_id]
      search_filters << { range: { id: { gte: p[:min_id] } } }
    end
    if p[:max_id]
      search_filters << { range: { id: { lte: p[:max_id] } } }
    end

    { where: search_wheres,
      complex_wheres: complex_wheres,
      filters: search_filters,
      per_page: p[:per_page] || 30,
      page: p[:page],
      sort: sort,
      extra_preloads: extra_preloads }
  end

  private

  def self.conservation_condition(es_field, values, params)
    # use a nested query to search the specified fiels
    status_condition = {
      nested: {
        path: "taxon.statuses",
        query: { filtered: { query: {
          bool: { must: [ { terms: {
            "taxon.statuses.#{ es_field }" => values
          } } ] }
        } } }
      }
    }
    if params[:place_id]
      # if a place condition is specified, return all results
      # from the place(s) specified, or where place is NULL
      status_condition[:nested][:query][:filtered][:filter] = { bool: { should: [
        { terms: { "taxon.statuses.place_id" =>
          [ params[:place_id] ].flatten.map{ |v| ElasticModel.id_or_object(v) } } },
        { missing: { field: "taxon.statuses.place_id" } }
      ] } }
    else
      # no place condition specified, so apply a `place is NULL` condition
      status_condition[:nested][:query][:filtered][:filter] = [
        { missing: { field: "taxon.statuses.place_id" } }
      ]
    end
    status_condition
  end

  def add_taxon_statuses(json, t)
    # taxa can be globally threatened, but need context for the rest
    if json[:place_ids].empty?
      json[:taxon][:threatened] = t.threatened?
      json[:taxon][:introduced] = false
      json[:taxon][:native] = false
      json[:taxon][:endemic] = false
      return
    end
    places = indexed_places ||
      Place.where(id: json[:place_ids]).select(:id, :ancestry).to_a
    json[:taxon][:threatened] = t.threatened?(place: places)
    json[:taxon][:introduced] = t.establishment_means_in_place?(
      ListedTaxon::INTRODUCED_EQUIVALENTS, places, closest: true)
    # if the taxon is introduced it cannot be native or endemic
    if json[:taxon][:introduced]
      json[:taxon][:native] = false
      json[:taxon][:endemic] = false
      return
    end
    json[:taxon][:native] = t.establishment_means_in_place?(
      ListedTaxon::NATIVE_EQUIVALENTS, places, closest: true)
    json[:taxon][:endemic] = t.establishment_means_in_place?(
      "endemic", places)
  end

  # returns an array of change hashes:
  #   [ { field_name: "geom", changed_at: ... },
  #     { field_name: "curator_identification_id",
  #       project_id: 1, changed_at: ... } ]
  def field_changes_to_index
    # get all the changes for this observation
    changes = model_attribute_changes.map do |c|
      { field_name: c.field_name, changed_at: c.changed_at }
    end
    # get all the project curator IDs for this obs
    if project_observations_with_changes.length > 0
      changes += project_observations_with_changes.map do |po|
        po.model_attribute_changes.map do |c|
          return unless c.field_name == "curator_identification_id"
          { field_name: "project_curator_id", project_id: po.project_id,
              changed_at: c.changed_at }
        end
      end.flatten.compact
    end
    changes
  end

end
