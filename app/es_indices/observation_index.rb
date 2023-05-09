class Observation < ApplicationRecord

  include ActsAsElasticModel

  DEFAULT_ES_BATCH_SIZE = 100
  DEFAULT_ES_BATCH_SLEEP = 2

  attr_accessor :indexed_place_ids, :indexed_private_place_ids, :indexed_private_places

  scope :load_for_index, -> { includes(
    { user: [ :flags, :stored_preferences ] }, :confirmed_reviews, :flags,
    :observation_links, :quality_metrics,
    :votes_for, :stored_preferences, :tags,
    { annotations: :votes_for },
    { photos: :flags },
    { sounds: :user },
    { identifications: [ :stored_preferences, :taxon ] }, :project_observations,
    { taxon: [ :conservation_statuses ] },
    { observation_field_values: :observation_field },
    { comments: [ { user: :flags }, :flags, :moderator_actions ] } ) }
  settings index: { number_of_shards: Rails.env.production? ? 12 : 4, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :annotations, type: :nested do
        indexes :concatenated_attr_val, type: "keyword"
        indexes :controlled_attribute_id, type: "short" do
          indexes :keyword, type: "keyword"
        end
        indexes :controlled_value_id, type: "short" do
          indexes :keyword, type: "keyword"
        end
        indexes :resource_type, type: "keyword"
        indexes :uuid, type: "keyword"
        indexes :user_id, type: "keyword"
        indexes :vote_score, type: "byte"
        indexes :votes do
          indexes :created_at, type: "date", index: false
          indexes :id, type: "integer", index: false
          indexes :user_id, type: "integer", index: false
          indexes :vote_flag, type: "boolean", index: false
        end
      end
      indexes :cached_votes_total, type: "short"
      indexes :captive, type: "boolean"
      indexes :comments do
        indexes :body, type: "text", analyzer: "ascii_snowball_analyzer"
        indexes :created_at, type: "date", index: false
        indexes :created_at_details do
          indexes :date, type: "date", index: false
          indexes :day, type: "byte", index: false
          indexes :hour, type: "byte", index: false
          indexes :month, type: "byte", index: false
          indexes :week, type: "byte", index: false
          indexes :year, type: "short", index: false
        end
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
        indexes :hidden, type: "boolean"
        indexes :id, type: "integer"
        indexes :moderator_actions do
          indexes :action, type: "keyword", index: false
          indexes :created_at, type: "date"
          indexes :created_at_details do
            indexes :date, type: "date", index: false
            indexes :day, type: "byte", index: false
            indexes :hour, type: "byte", index: false
            indexes :month, type: "byte", index: false
            indexes :week, type: "byte", index: false
            indexes :year, type: "short", index: false
          end
          indexes :id, type: "integer"
          indexes :reason, type: "text", analyzer: "ascii_snowball_analyzer", index: false
          indexes :user do
            indexes :created_at, type: "date"
            indexes :id, type: "integer"
            indexes :login, type: "keyword"
            indexes :spam, type: "boolean"
            indexes :suspended, type: "boolean"
            indexes :site_id, type: "integer"
          end
        end
        indexes :user do
          indexes :created_at, type: "date"
          indexes :id, type: "integer"
          indexes :login, type: "keyword"
          indexes :spam, type: "boolean"
          indexes :suspended, type: "boolean"
          indexes :uuid, type: "keyword"
        end
        indexes :uuid, type: "keyword"
      end
      indexes :comments_count, type: "short"
      indexes :community_taxon_id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :context_geoprivacy, type: "keyword"
      indexes :context_taxon_geoprivacy, type: "keyword"
      indexes :context_user_geoprivacy, type: "keyword"
      indexes :created_at, type: "date"
      indexes :created_at_details do
        indexes :date, type: "date"
        indexes :day, type: "byte"
        indexes :hour, type: "byte"
        indexes :month, type: "byte"
        indexes :week, type: "byte"
        indexes :year, type: "short"
      end
      indexes :created_time_zone, type: "keyword", index: false
      indexes :description, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :faves_count, type: "short"
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
      indexes :geoprivacy, type: "keyword"
      indexes :id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :id_please, type: "boolean"
      indexes :ident_taxon_ids, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :identification_categories, type: "keyword"
      indexes :identifications_count, type: "short"
      indexes :identifications_most_agree, type: "boolean"
      indexes :identifications_most_disagree, type: "boolean"
      indexes :identifications_some_agree, type: "boolean"
      indexes :identifier_user_ids, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :license_code, type: "keyword"
      indexes :location, type: "geo_point"
      indexes :map_scale, type: "byte"
      indexes :mappable, type: "boolean"
      indexes :non_owner_identifier_user_ids, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :num_identification_agreements, type: "short"
      indexes :num_identification_disagreements, type: "short"
      indexes :oauth_application_id, type: "short" do
        indexes :keyword, type: "keyword"
      end
      indexes :obscured, type: "boolean"
      indexes :observed_on, type: "date", format: "date_optional_time"
      indexes :observed_on_details do
        indexes :date, type: "date"
        indexes :day, type: "byte"
        indexes :hour, type: "byte"
        indexes :month, type: "byte"
        indexes :week, type: "byte"
        indexes :year, type: "short"
      end
      indexes :observed_on_string, type: "text"
      indexes :observed_time_zone, type: "keyword", index: false
      indexes :ofvs, type: :nested do
        indexes :datatype, type: "keyword"
        indexes :field_id, type: "integer"
        indexes :id, type: "integer"
        indexes :name, type: "keyword"
        indexes :name_ci, type: "text", analyzer: "keyword_analyzer"
        indexes :taxon_id, type: "integer"
        indexes :user_id, type: "integer"
        indexes :uuid, type: "keyword"
        indexes :value, type: "keyword"
        indexes :value_ci, type: "text", analyzer: "keyword_analyzer"
      end
      # TODO Remove out_of_range from the index
      indexes :out_of_range, type: "boolean"
      indexes :outlinks do
        indexes :source, type: "keyword"
        indexes :url, type: "keyword"
      end
      indexes :owners_identification_from_vision, type: "boolean"
      indexes :photo_licenses, type: "keyword"
      indexes :photos_count, type: "short"
      indexes :place_guess, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :place_ids, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :positional_accuracy, type: "integer"
      indexes :preferences do
        indexes :name, type: "keyword", index: false
        indexes :value, type: "keyword", index: false
      end
      indexes :private_geojson, type: "geo_shape"
      indexes :private_location, type: "geo_point"
      indexes :private_place_guess, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :private_place_ids, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :project_ids, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :project_ids_with_curator_id, type: "keyword"
      indexes :project_ids_without_curator_id, type: "keyword"
      indexes :public_positional_accuracy, type: "integer"
      indexes :quality_grade, type: "keyword"
      indexes :quality_metrics do
        indexes :agree, type: "boolean"
        indexes :id, type: "integer"
        indexes :metric, type: "keyword", index: false
        indexes :user_id, type: "integer"
      end
      indexes :reviewed_by, type: "keyword"
      indexes :site_id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :sound_licenses, type: "keyword"
      indexes :sounds do
        indexes :attribution, type: "keyword", index: false
        indexes :file_content_type, type: "keyword", index: false
        indexes :file_url, type: "keyword", index: false
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
        indexes :id, type: "integer"
        indexes :license_code, type: "keyword"
        indexes :native_sound_id, type: "keyword", index: false
        indexes :play_local, type: "boolean"
        indexes :secret_token, type: "keyword", index: false
        indexes :subtype, type: "keyword"
      end
      indexes :sounds_count, type: "short"
      indexes :spam, type: "boolean"
      indexes :species_guess, type: "keyword"
      indexes :tags, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :taxon do
        indexes :ancestor_ids, type: "integer" do
          indexes :keyword, type: "keyword"
        end
        indexes :ancestry, type: "keyword"
        indexes :endemic, type: "boolean"
        indexes :extinct, type: "boolean"
        indexes :iconic_taxon_id, type: "integer" do
          indexes :keyword, type: "keyword"
        end
        indexes :id, type: "integer" do
          indexes :keyword, type: "keyword"
        end
        indexes :introduced, type: "boolean"
        indexes :is_active, type: "boolean"
        indexes :min_species_ancestry, type: "keyword"
        indexes :min_species_taxon_id, type: "integer"
        indexes :name, type: "text", analyzer: "ascii_snowball_analyzer"
        indexes :native, type: "boolean"
        indexes :parent_id, type: "integer" do
          indexes :keyword, type: "keyword"
        end
        indexes :rank, type: "keyword"
        indexes :rank_level, type: "scaled_float", scaling_factor: 100
        indexes :statuses, type: :nested do
          indexes :authority, type: "keyword"
          indexes :geoprivacy, type: "keyword"
          indexes :iucn, type: "byte"
          indexes :place_id, type: "keyword"
          indexes :source_id, type: "short"
          indexes :status, type: "keyword"
          indexes :status_name, type: "keyword"
          indexes :user_id, type: "integer"
        end
        indexes :threatened, type: "boolean"
        indexes :uuid, type: "keyword"
      end
      indexes :taxon_geoprivacy, type: "keyword"
      indexes :time_observed_at, type: "date"
      indexes :time_zone_offset, type: "keyword", index: false
      indexes :updated_at, type: "date"
      indexes :uri, type: "keyword", index: false
      indexes :user do
        indexes :created_at, type: "date"
        indexes :id, type: "integer" do
          indexes :keyword, type: "keyword"
        end
        indexes :login, type: "keyword"
        indexes :site_id, type: "integer"
        indexes :spam, type: "boolean"
        indexes :suspended, type: "boolean"
        indexes :uuid, type: "keyword"
      end
      indexes :uuid, type: "keyword"
      indexes :votes, type: :nested do
        indexes :created_at, type: "date"
        indexes :id, type: "integer"
        indexes :user_id, type: "integer"
        indexes :vote_flag, type: "boolean"
        indexes :vote_scope, type: "keyword"
      end
    end
  end

  # Obs as a JSON document for indexing in Elastic Search. If you're going to
  # modify this, make sure you also modify the mapping above and add an explicit
  # type for each new field. That mapping is only used for recreating the index,
  # though, so you should also update the actual index as well (see
  # 20151030205931_add_mappings_to_observations_index.rb for an example)
  def as_indexed_json(options={})
    preload_for_elastic_index unless options[:no_details]
    # some timezones are invalid
    created = created_at.in_time_zone(timezone_object || "UTC")
    t = taxon
    json = {
      id: id,
      site_id: site_id,
      created_at: created,
      created_at_details: ElasticModel.date_details(created),
      observed_on: datetime.blank? ? nil : datetime.to_date,
      observed_on_details: ElasticModel.date_details(datetime),
      time_observed_at: time_observed_at_in_zone,
      place_ids: (indexed_place_ids || public_places.map(&:id)).compact.uniq,
      quality_grade: quality_grade,
      taxon: t ? t.as_indexed_json(for_observation: true,
        no_details: options[:no_details],
        for_identification: options[:for_identification]) : nil
    }

    current_ids = identifications.select(&:current?)
    if options[:no_details]
      json.merge!({
        user_id: user.id
      })
    else
      json.merge!({
        uuid: uuid,
        user: user ? user.as_indexed_json(no_details: true).merge( site_id: user.site_id ) : nil,
        captive: captive,
        created_time_zone: timezone_object.blank? ? "UTC" : timezone_object.tzinfo.name,
        updated_at: updated_at.in_time_zone(timezone_object || "UTC"),
        observed_time_zone: timezone_object.blank? ? nil : timezone_object.tzinfo.name,
        time_zone_offset: timezone_offset,
        uri: uri,
        description: description,
        mappable: mappable,
        species_guess: species_guess.blank? ? nil : species_guess,
        place_guess: place_guess.blank? ? nil : place_guess,
        private_place_guess: private_place_guess.blank? ? nil : private_place_guess,
        observed_on_string: observed_on_string,
        license_code: license ? license.downcase : nil,
        geoprivacy: geoprivacy,
        taxon_geoprivacy: taxon_geoprivacy,
        map_scale: map_scale,
        oauth_application_id: application_id_to_index,
        community_taxon_id: community_taxon_id,
        faves_count: faves_count,
        # cached_votes_total is a count of *all* votes on the obs, which
        # includes things voting whether the obs still needs an ID, so using
        # that actually throws off the sorting when what we really want to do is
        # sort by faves. We're not losing anything performance-wise by loading
        # the votes since we're doing that in the `votes` attribute anyway
        cached_votes_total: votes_for.select{|v| v.vote_scope.blank?}.size,
        num_identification_agreements: num_identification_agreements,
        num_identification_disagreements: num_identification_disagreements,
        identifications_most_agree:
          (num_identification_agreements > num_identification_disagreements),
        identifications_some_agree:
          (num_identification_agreements > 0),
        identifications_most_disagree:
          (num_identification_agreements < num_identification_disagreements),
        place_ids: (indexed_place_ids || public_places.map(&:id)).compact.uniq,
        private_place_ids: (indexed_private_place_ids || places.map(&:id)).compact.uniq,
        project_ids: project_observations.map{ |po| po[:project_id] }.compact.uniq,
        project_ids_with_curator_id: project_observations.
          select{ |po| !po.curator_identification_id.nil? }.map(&:project_id).compact.uniq,
        project_ids_without_curator_id: project_observations.
          select{ |po| po.curator_identification_id.nil? }.map(&:project_id).compact.uniq,
        reviewed_by: confirmed_reviews.map(&:user_id),
        tags: tags.map(&:name).compact.uniq,
        ofvs: observation_field_values.uniq.map(&:as_indexed_json),
        annotations: annotations.map(&:as_indexed_json),
        photos_count: photos.any? ? photos.select{|p|
          p.flags.detect{|f| f.flag == Flag::COPYRIGHT_INFRINGEMENT && !f.resolved?}.blank?
        }.length : nil,
        sounds_count: sounds.any? ? sounds.length : nil,
        photo_licenses: photos.map(&:index_license_code).compact.uniq,
        sound_licenses: sounds.map(&:index_license_code).compact.uniq,
        sounds: sounds.map(&:as_indexed_json),
        identifier_user_ids: current_ids.map(&:user_id),
        ident_taxon_ids: current_ids.map{|i| i.taxon.self_and_ancestor_ids rescue []}.flatten.uniq,
        non_owner_identifier_user_ids: current_ids.map(&:user_id) - [user_id],
        identification_categories: current_ids.map(&:category).uniq,
        identifications_count: num_identifications_by_others,
        comments: comments.map(&:as_indexed_json),
        comments_count: comments.size,
        obscured: coordinates_obscured? || geoprivacy_obscured?,
        positional_accuracy: positional_accuracy,
        public_positional_accuracy: public_positional_accuracy,
        location: (latitude && longitude) ?
          ElasticModel.point_latlon(latitude, longitude) : nil,
        private_location: (private_latitude && private_longitude) ?
          ElasticModel.point_latlon(private_latitude, private_longitude) : nil,
        geojson: (latitude && longitude) ?
          ElasticModel.point_geojson(latitude, longitude) : nil,
        private_geojson: (private_latitude && private_longitude) ?
          ElasticModel.point_geojson(private_latitude, private_longitude) : nil,
        votes: votes_for.map(&:as_indexed_json),
        outlinks: observation_links.map(&:as_indexed_json),
        owners_identification_from_vision: owners_identification_from_vision,
        preferences: preferences.map{ |p| { name: p[0], value: p[1] } },
        flags: flags.map(&:as_indexed_json),
        quality_metrics: quality_metrics.map(&:as_indexed_json),
        spam: known_spam? || owned_by_spammer?
      })

      add_taxon_statuses(json, t) if t && json[:taxon]
    end
    json
  end

  # to quickly fetch observation place_ids when bulk indexing
  def self.prepare_batch_for_index(observations, options = {})
    # make sure we default all caches to empty arrays
    # this prevents future lookups for instances with no results
    observations.each{ |o|
      o.indexed_place_ids ||= [ ]
      o.indexed_private_place_ids ||= [ ]
      o.indexed_private_places ||= [ ]
      o.taxon_introduced ||= false
      o.taxon_native ||= false
      o.taxon_endemic ||= false
    }
    batch_ids_string = observations.map(&:id).join(",")
    return if batch_ids_string.blank?
    # fetch all place_ids store them in `indexed_place_ids`
    if options.blank? || options[:places]
      observation_private_place_ids = { }
      connection.execute("
        SELECT observation_id, place_id
        FROM observations_places
        WHERE observation_id IN (#{ batch_ids_string })").to_a.each do |r|
        observation_private_place_ids[r["observation_id"]] ||= []
        observation_private_place_ids[r["observation_id"]] << r["place_id"]
      end
      observations.each do |o|
        if observation_private_place_ids[o.id]
          o.indexed_private_place_ids = observation_private_place_ids[o.id]
        end
      end
      private_place_ids = observations.map(&:indexed_private_place_ids).flatten.uniq.compact
      private_places_by_id = Hash[ Place.where(id: private_place_ids).map{ |p| [ p.id, p ] } ]
      always_indexed_place_levels = [
        Place::COUNTRY_LEVEL,
        Place::STATE_LEVEL,
        Place::COUNTY_LEVEL
      ]
      observations.each do |o|
        unless o.indexed_private_place_ids.blank?
          o.indexed_private_places = private_places_by_id.values_at(*o.indexed_private_place_ids).compact.select do |p|
            always_indexed_place_levels.include?( p.admin_level ) ||
            Observation.places_without_obscuration_protection.include?( p.id ) ||
            p.bbox_privately_contains_observation?( o )
          end
          o.indexed_private_place_ids = o.indexed_private_places.map(&:id)
          unless o.latitude.blank? || o.geoprivacy == Observation::PRIVATE || o.taxon_geoprivacy == Observation::PRIVATE
            o.indexed_place_ids = o.indexed_private_places.select {|p|
              always_indexed_place_levels.include?( p.admin_level ) ||
              Observation.places_without_obscuration_protection.include?( p.id ) ||
              p.bbox_publicly_contains_observation?( o )
            }.map(&:id)
          end
        end
      end
    end

    if options.blank?
      taxon_establishment_places = { }
      taxon_ids = observations.map(&:taxon_id).compact.uniq
      uniq_obs_place_ids = observations.map{ |o|o.indexed_private_places.map(&:path_ids) }.flatten.compact.uniq.join(',')
      return if uniq_obs_place_ids.empty? || taxon_ids.empty?
      Observation.connection.execute("
        SELECT taxon_id, establishment_means, place_id
        FROM listed_taxa
        WHERE taxon_id IN (#{ taxon_ids.join(',') })
        AND place_id IN (#{ uniq_obs_place_ids })
        AND establishment_means IS NOT NULL").to_a.each do |r|
        taxon_establishment_places[r["taxon_id"]] ||= {}
        taxon_establishment_places[r["taxon_id"]][r["establishment_means"]] ||= []
        taxon_establishment_places[r["taxon_id"]][r["establishment_means"]] << r["place_id"]
      end
      place_ids = taxon_establishment_places.values.map(&:values).flatten.uniq.map(&:to_i)
      return if place_ids.empty?
      places = {}
      Place.connection.execute("
        SELECT id, bbox_area
        FROM places WHERE id IN (#{ place_ids.join(',') })").to_a.each do |r|
        places[r["id"]] = {
          id: r["id"],
          bbox_area: r["bbox_area"].to_f
        }
      end
      taxon_places = { }
      taxon_endemic_place_ids = { }
      taxon_establishment_places.each do |taxon_id, means_places|
        taxon_places[taxon_id] ||= { }
        taxon_endemic_place_ids[taxon_id] ||= []
        means_places.each do |means,place_ids|
          taxon_establishment_places[taxon_id][means] ||= []
          # keep a hash of all places for each taxon
          place_ids.each do |place_id|
            taxon_places[taxon_id][place_id] ||= places[place_id].dup
            taxon_places[taxon_id][place_id] ||= { }
            taxon_places[taxon_id][place_id][means] = true
          end
          if means == "endemic"
            taxon_endemic_place_ids[taxon_id] += place_ids
          end
        end
      end
      observations.each do |o|
        if o.taxon && taxon_places[o.taxon.id]
          closest = taxon_places[o.taxon.id].
            slice(*o.indexed_private_places.map(&:path_ids).flatten.compact.uniq).
            values.sort_by{ |p| p[:bbox_area] || 0 }.first
          o.taxon_introduced = !!(closest &&
            closest.values_at(*ListedTaxon::INTRODUCED_EQUIVALENTS).compact.any?)
          o.taxon_native = !!(closest &&
            closest.values_at(*ListedTaxon::NATIVE_EQUIVALENTS).compact.any?)
          o.taxon_endemic = (o.indexed_private_place_ids & taxon_endemic_place_ids[o.taxon.id]).any?
        end
      end
    end
  end

  def self.matching_taxon_ids( search_term )
    filters = [
      { term: { is_active: true } },
      {
        nested: {
          path: "names",
          query: {
            match: {
              "names.name": {
                query: search_term,
                operator: "and"
              }
            }
          }
        }
      }
    ]
    search_result = Taxon.elastic_search(filters: filters, source: [:id], size: 2000 )
    return search_result.results.results.map( &:id ).map( &:to_i )
  end

  def self.params_to_elastic_query(params, options = {})
    current_user = options[:current_user] || params[:viewer]
    p = params[:_query_params_set] ? params : query_params(params)
    # one of the param initializing steps saw an impossible condition
    return nil if p[:empty_set]
    p = site_search_params(options[:site], p)
    search_filters = [ ]
    inverse_filters = [ ]
    extra_preloads = [ ]
    q = p[:q] unless p[:q].blank?
    search_on = p[:search_on] if Observation::FIELDS_TO_SEARCH_ON.include?(p[:search_on])
    if q
      if search_on === "names"
        search_taxa = true
        searched_taxa = matching_taxon_ids( q )
      elsif search_on === "tags"
        fields = [ :tags ]
      elsif search_on === "description"
        fields = [ :description ]
      elsif search_on === "place"
        fields = [ :place_guess ]
      else
        fields = [ :tags, :description, :place_guess ]
        search_taxa = true
        searched_taxa = matching_taxon_ids( q )
      end
      if searched_taxa && !searched_taxa.empty?
        taxon_search_filter = { terms: { "taxon.id" => searched_taxa } }
      end
      if fields && !fields.empty?
        match_filter = { multi_match: { query: q, operator: "and", fields: fields } }
      end
      if match_filter && taxon_search_filter
        search_filters << {
          bool: {
            should: [
              match_filter,
              taxon_search_filter
            ]
          }
        }
      elsif match_filter
        search_filters << match_filter
      elsif search_taxa
        search_filters << ( taxon_search_filter || { term: { id: -1 } } )
      end
    end
    if p[:user]
      search_filters << { term: {
        "user.id.keyword" => ElasticModel.id_or_object(p[:user]) } }
    elsif p[:user_id]
      search_filters << { terms: {
        "user.id.keyword" => [ p[:user_id] ].flatten.map{ |u| ElasticModel.id_or_object(u) } } }
    end

    # params to search based on value
    [ { http_param: :rank, es_field: "taxon.rank" },
      { http_param: :observed_on_day, es_field: "observed_on_details.day" },
      { http_param: :observed_on_month, es_field: "observed_on_details.month" },
      { http_param: :observed_on_year, es_field: "observed_on_details.year" },
      { http_param: :day, es_field: "observed_on_details.day" },
      { http_param: :month, es_field: "observed_on_details.month" },
      { http_param: :year, es_field: "observed_on_details.year" },
      { http_param: :week, es_field: "observed_on_details.week" },
      { http_param: :site_id, es_field: "site_id.keyword" },
      { http_param: :id, es_field: "id" }
    ].each do |filter|
      unless p[ filter[:http_param] ].blank? || p[ filter[:http_param] ] == "any"
        search_filters << { terms: { filter[:es_field] =>
          [ p[ filter[:http_param] ] ].flatten.map{ |v|
            ElasticModel.id_or_object(v) } } }
      end
    end

    # Place searches require special handling if the user is asking for their
    # own observations
    params_user_ids = [p[:user_id]].flatten.map(&:to_i)
    unless p[:place_id].blank? || p[:place_id] == "any"
      if p[:viewer] && params_user_ids.size == 1 && p[:viewer].id == params_user_ids[0]
        search_filters << { terms: { "private_place_ids.keyword" => [ p[:place_id] ].flatten.map{ |v|
          ElasticModel.id_or_object(v)
        } } }
      else
        search_filters << { terms: { "place_ids.keyword" => [ p[:place_id] ].flatten.map{ |v|
          ElasticModel.id_or_object(v)
        } } }
      end
    end

    unless p[:not_in_place].blank?
      place_ids = [p[:not_in_place]].flatten.map {| v | ElasticModel.id_or_object( v ) }
      inverse_filters << if ( params_user_ids.size == 1 && p[:viewer]&.id == params_user_ids[0] )
        { terms: { "private_place_ids.keyword" => place_ids } }
      else
        { terms: { "place_ids.keyword" => place_ids } }
      end
    end

    # params that can be true / false / any
    [ { http_param: :introduced, es_field: "taxon.introduced" },
      { http_param: :threatened, es_field: "taxon.threatened" },
      { http_param: :native, es_field: "taxon.native" },
      { http_param: :endemic, es_field: "taxon.endemic" },
      # TODO remove id_please when we remove it from the ES index
      { http_param: :id_please, es_field: "id_please" },
      # TODO remove out_of_range when we remove it from the ES index
      { http_param: :out_of_range, es_field: "out_of_range" },
      { http_param: :mappable, es_field: "mappable" },
      { http_param: :captive, es_field: "captive" },
      { http_param: :spam, es_field: "spam" }
    ].each do |filter|
      if p[ filter[:http_param] ].yesish?
        search_filters << { term: { filter[:es_field] => true } }
      elsif p[ filter[:http_param] ].noish?
        search_filters << { term: { filter[:es_field] => false } }
      end
    end

    # params that can check for presence of something
    [ { http_param: :with_photos, es_field: "photos_count" },
      { http_param: :with_sounds, es_field: "sounds_count" },
      { http_param: :with_geo, es_field: "geojson" },
      { http_param: :identified, es_field: "taxon" },
    ].each do |filter|
      f = { exists: { field: filter[:es_field] } }
      if p[ filter[:http_param] ].yesish?
        search_filters << f
      elsif p[ filter[:http_param] ].noish?
        inverse_filters << f
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
        "taxon.ancestor_ids.keyword" => ElasticModel.id_or_object(p[:observations_taxon]) } }
    elsif p[:observations_taxon_ids]
      search_filters << { terms: {
        "taxon.ancestor_ids.keyword" => p[:observations_taxon_ids] } }
    end
    if p[:without_observations_taxon]
      inverse_filters << {
        term: {
          "taxon.ancestor_ids.keyword" => ElasticModel.id_or_object( p[:without_observations_taxon] )
        }
      }
    end
    if p[:license] == "any"
      search_filters << { exists: { field: "license_code" } }
    elsif p[:license] == "none"
      inverse_filters << { exists: { field: "license_code" } }
    elsif p[:license].is_a?( String )
      search_filters << { terms: { license_code:
        [ p[:license].to_s.split( "," ) ].flatten.compact.map{ |l| l.downcase } } }
    elsif p[:license].is_a?( Array )
      search_filters << { terms: { license_code:
        [ p[:license] ].flatten.compact.map{ |l| l.downcase } } }
    end
    if p[:photo_license] == "any"
      search_filters << { exists: { field: "photo_licenses" } }
    elsif p[:photo_license] == "none"
      inverse_filters << { exists: { field: "photo_licenses" } }
    elsif p[:photo_license]
      licenses = if p[:photo_license].is_a?( String )
        [ p[:photo_license].to_s.split( "," ) ].flatten.compact.map{ |l| l.downcase }
      else
        [ p[:photo_license] ].flatten.compact.map{ |l| l.downcase }
      end
      search_filters << { terms: { "photo_licenses" => licenses } }
    end
    if p[:sound_license] == "any"
      search_filters << { exists: { field: "sound_licenses" } }
    elsif p[:sound_license] == "none"
      inverse_filters << { exists: { field: "sound_licenses" } }
    elsif p[:sound_license]
      licenses = [ p[:sound_license] ].flatten.map{ |l| l.downcase }
      search_filters << { terms: { "sound_licenses" => licenses } }
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
      inverse_filters << { term: { "project_ids.keyword":
        ElasticModel.id_or_object(p[:not_in_project]) } }
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
          { bool: { must_not: { exists: { field: "taxon.iconic_taxon_id" } } } }
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
        inverse_filters << { term: { reviewed_by: current_user.id } }
      end
    end

    if p[:d1] || p[:d2]
      p[:d1] = p[:d1].to_s
      d1 = DateTime.parse(p[:d1]) rescue DateTime.parse("1800-01-01")
      p[:d2] = p[:d2].to_s
      d2 = DateTime.parse(p[:d2]) rescue Time.now
      # d2 = Time.now if d2 && d2 > Time.now # not sure why we need to prevent queries into the future
      query_by_date = (
        (!p[:d1].blank? && d1.to_s =~ /00:00:00/ && p[:d1] !~ /00:00:00/) ||
        (!p[:d2].blank? && d2.to_s =~ /00:00:00/ && p[:d2] !~ /00:00:00/))
      date_filter = { "observed_on_details.date": {
        gte: d1.strftime("%F"),
        lte: d2.strftime("%F") }}
      if query_by_date
        search_filters << { range: date_filter }
      else
        time_filter = { time_observed_at: {
          gte: d1.strftime("%FT%T%:z"),
          lte: d2.strftime("%FT%T%:z") } }
        search_filters << { bool: { should: [
          { bool: { must: [ { range: time_filter }, { exists: { field: "time_observed_at" } } ] } },
          { bool: {
            must: { range: date_filter },
            must_not: { exists: { field: "time_observed_at" } } } }
        ] } }
      end
    end

    if p[:created_d1] || p[:created_d2]
      created_d1 = DateTime.parse(p[:created_d1]) rescue DateTime.parse("1800-01-01")
      created_d2 = DateTime.parse(p[:created_d2]) rescue Time.now
      if p[:created_d2] && created_d2.to_s =~ /00:00:00/ && p[:created_d2] !~ /00:00:00/
        # if you provide a date like 2018-02-01, the DateTime will be Thu, 01
        # Feb 2018 00:00:00 +0000, so to perform an inclusive search you want
        # another day
        created_d2 = created_d2 + 1.day
      end
      search_filters << {
        range: {
          "created_at": {
            gte: created_d1.strftime( "%FT%T%:z" ),
            lte: created_d2.strftime( "%FT%T%:z" )
          }
        }
      }
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
          { terms: { "user.id.keyword" => p[:aggregation_user_ids] } }
        ] } }
      end
    end

    if p[:term_id]
      nested_query = {
        nested: {
          path: "annotations",
          query: { bool: { must: [
            { terms: { "annotations.controlled_attribute_id.keyword": p[:term_id].to_s.split( "," ) } },
            { range: { "annotations.vote_score": { gte: 0 } } }
          ] }
          }
        }
      }
      if p[:term_value_id]
        nested_query[:nested][:query][:bool][:must] <<
          { terms: { "annotations.controlled_value_id.keyword": p[:term_value_id].to_s.split( "," ) } }
      end
      search_filters << nested_query
    end

    if p[:ofv_params]
      p[:ofv_params].each do |k,v|
        # use a nested query to search within a single nested
        # object and not across all nested objects
        nested_query = {
          nested: {
            path: "ofvs",
            query: { bool: { must: [ { match: {
              "ofvs.name_ci" => v[:observation_field].name } } ] }
            }
          }
        }
        unless v[:value].blank?
          nested_query[:nested][:query][:bool][:must] <<
            { match: { "ofvs.value_ci" => v[:value] } }
        end
        search_filters << nested_query
      end
    end

    if p[:ofv_datatype]
      vals = p[:ofv_datatype].to_s.split( "," )
      search_filters << {
        nested: {
          path: "ofvs",
          query: {
            bool: {
              filter: [
                {
                  terms: {
                    "ofvs.datatype" => vals
                  }
                }
              ]
            }
          }
        }
      }
    end

    if p[:ident_user_id]
      vals = p[:ident_user_id].to_s.split( "," )
      search_filters << { terms: { "identifier_user_ids.keyword": vals } }
    end

    if p[:ident_taxon_id]
      vals = p[:ident_taxon_id].to_s.split( "," )
      search_filters << { terms: { "ident_taxon_ids.keyword": vals } }
    end

    # conservation status
    unless p[:cs].blank?
      values = [ p[:cs] ].flatten.map(&:downcase)
      search_filters << conservation_condition(:status, values, p)
    end
    # IUCN conservation status
    unless p[:csi].blank?
      iucn_equivs = [ p[:csi] ].flatten.map{ |v|
        Taxon::IUCN_CODE_VALUES[v.upcase] }.compact.uniq
      unless iucn_equivs.blank?
        search_filters << conservation_condition(:iucn, iucn_equivs, p)
      end
    end
    # conservation status authority
    unless p[:csa].blank?
      values = [ p[:csa] ].flatten.map(&:downcase)
      search_filters << conservation_condition(:authority, values, p)
    end
    if p[:acc_above].to_i > 0
      search_filters << { range: { positional_accuracy: { gt: p[:acc_above].to_i } } }
    end
    if p[:acc_below].to_i > 0
      search_filters << { range: { positional_accuracy: { lt: p[:acc_below].to_i } } }
    end
    if p[:acc_below_or_unknown].to_i > 0
      search_filters << {
        bool: {
          should: [
            {
              range: {
                positional_accuracy: {
                  lt: p[:acc_below_or_unknown].to_i
                }
              }
            },
            {
              bool: {
                must_not: [
                  {
                    exists: {
                      field: "positional_accuracy"
                    }
                  }
                ]
              }
            }
          ]
        }
      }
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
    when "random"
      "random"
    else
      { created_at: sort_order }
    end

    [:geoprivacy, :taxon_geoprivacy].each do |geoprivacy_type|
      unless p[geoprivacy_type].blank? || p[geoprivacy_type] == "any"
        case p[geoprivacy_type]
        when Observation::OPEN
          search_filters << { bool: { should: [
            { term: { geoprivacy_type => "open" } },
            { bool: { must_not: { exists: { field: geoprivacy_type } } } }
          ]}}
        when "obscured_private"
          search_filters << { terms: { geoprivacy_type => Observation::GEOPRIVACIES } }
        else
          search_filters << { term: { geoprivacy_type => p[geoprivacy_type] } }
        end
      end
    end

    if p[:popular].yesish?
      search_filters << { range: { cached_votes_total: { gte: 1 } } }
    elsif p[:popular].noish?
      search_filters << { term: { cached_votes_total: 0 } }
    end
    if p[:min_id]
      id_filter = { range: { id: { gte: p[:min_id] } } }
      id_filter[:range][:id][:lte] = p[:max_id] if p[:max_id]
      search_filters << id_filter
    elsif p[:max_id]
      search_filters << { range: { id: { lte: p[:max_id] } } }
    end
    if p[:id_above]
      search_filters << { range: { id: { gt: p[:id_above] } } }
    end
    if p[:id_below]
      search_filters << { range: { id: { lt: p[:id_below] } } }
    end

    { filters: search_filters,
      inverse_filters: inverse_filters,
      per_page: p[:per_page] || 30,
      page: p[:page],
      sort: sort,
      extra_preloads: extra_preloads,
      track_total_hits: !!p[:track_total_hits] }
  end

  private

  def self.conservation_condition(es_field, values, params)
    filters = [ { terms: { "taxon.statuses.#{ es_field }" => values } } ]
    inverse_filters = [ ]
    if params[:place_id]
      # if a place condition is specified, return all results
      # from the place(s) specified, or where place is NULL
      filters << { bool: { should: [
        { terms: { "taxon.statuses.place_id" =>
          [ params[:place_id] ].flatten.map{ |v| ElasticModel.id_or_object(v) } } },
        { bool: { must_not: { exists: { field: "taxon.statuses.place_id" } } } }
      ] } }
    else
      # no place condition specified, so apply a `place is NULL` condition
      inverse_filters << { exists: { field: "taxon.statuses.place_id" } }
    end
    bool = { must: filters }
    unless inverse_filters.blank?
      bool[:must_not] = inverse_filters
    end
    {
      nested: {
        path: "taxon.statuses",
        query: {
          bool: bool
        }
      }
    }
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
    places = indexed_private_places ||
      Place.where(id: json[:place_ids]).select(:id, :ancestry).to_a
    preloaded = taxon_introduced.yesish? || taxon_introduced.noish?
    json[:taxon][:threatened] = t.threatened?(place: places)
    json[:taxon][:introduced] = preloaded ? taxon_introduced :
      t.establishment_means_in_place?(ListedTaxon::INTRODUCED_EQUIVALENTS, places, closest: true)
    # if the taxon is introduced it cannot be native or endemic
    if json[:taxon][:introduced]
      json[:taxon][:native] = false
      json[:taxon][:endemic] = false
      return
    end
    json[:taxon][:native] = preloaded ? taxon_native :
      t.establishment_means_in_place?(ListedTaxon::NATIVE_EQUIVALENTS, places, closest: true)
    json[:taxon][:endemic] = preloaded ? taxon_endemic :
      t.establishment_means_in_place?("endemic", places)
    t.listed_taxa_with_establishment_means.reset
  end

end
