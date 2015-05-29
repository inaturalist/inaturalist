module ElasticModel

  # basic search analyzer. Avoids diacritic variations, uses snownall
  # for more tolerance of string endings (e.g. `bear` finds `bears`)
  ASCII_SNOWBALL_ANALYZER = {
    ascii_snowball_analyzer: {
      tokenizer: "standard",
      filter: [ "standard", "lowercase", "asciifolding", "stop", "snowball" ]
    }
  }
  # basic autocomplete analyzer. Avoids diacritic variations, will find
  # results based on sub-matches (e.g. `Park` finds `National Park`)
  AUTOCOMPLETE_ANALYZER = {
    autocomplete_analyzer: {
      tokenizer: "standard",
      filter: [ "standard", "lowercase", "asciifolding", "stop", "edge_ngram_filter" ]
    }
  }
  # autocomplete with no sub-matches (e.g. `Park` doesn't find `National Park`)
  KEYWORD_AUTOCOMPLETE_ANALYZER = {
    keyword_autocomplete_analyzer: {
      tokenizer: "keyword",
      filter: [ "standard", "lowercase", "asciifolding", "stop", "edge_ngram_filter" ]
    }
  }
  # basic search analyzer that allows sub-matches
  STANDARD_ANALYZER = {
    standard_analyzer: {
      tokenizer: "standard",
      filter: [ "standard", "lowercase", "asciifolding" ]
    }
  }
  # basic search analyzer with no sub-matches
  KEYWORD_ANALYZER = {
    keyword_analyzer: {
      tokenizer: "keyword",
      filter: [ "standard", "lowercase", "asciifolding" ]
    }
  }
  # for autocomplete analyzers. Needs at least 2 letters (e.g. `P` doesn't find `Park`)
  EDGE_NGRAM_FILTER =  {
    edge_ngram_filter: {
      type: "edgeNGram",
      min_gram: 2,
      max_gram: 15
    }
  }
  # store all of the above in a constant, used when defining indices in models
  ANALYSIS = {
    analyzer: [
      ASCII_SNOWBALL_ANALYZER,
      AUTOCOMPLETE_ANALYZER,
      KEYWORD_AUTOCOMPLETE_ANALYZER,
      STANDARD_ANALYZER,
      KEYWORD_ANALYZER
    ].reduce(&:merge),
    filter: EDGE_NGRAM_FILTER
  }

  def self.search_criteria(options={})
    return unless options && options.is_a?(Hash)
    criteria = [ ]
    options[:where] ||= { }
    options[:where].each do |key, value|
      if value.is_a?(Array) && ![ :should, :or ].include?(key)
        criteria << { terms: { key => value.map{ |v| id_or_object(v) } } }
      elsif value.is_a? Hash
        criteria << { key => value }
      else
        criteria << { match: { key => id_or_object(value) } }
      end
    end
    criteria
  end

  def self.search_filters(options={})
    return unless options && options.is_a?(Hash) &&
      options[:filters] && options[:filters].is_a?(Array)
    options[:filters].map do |f|
      next unless f.is_a?(Hash) && f.count == 1
      if f[:place]
        ElasticModel.place_filter(f)
      elsif f[:envelope]
        ElasticModel.envelope_filter(f)
      else
        f
      end
    end.compact
  end

  def self.search_hash(options={})
    criteria = ElasticModel.search_criteria(options)
    filters = ElasticModel.search_filters(options)
    query = criteria.blank? ?
      { match_all: { } } :
      { bool: { must: criteria } }
    # when there are filters, the query needs to be wrapped
    # in a filtered block that includes the filters being applied
    unless filters.blank?
      query = {
        filtered: {
          query: query,
          filter: {
            bool: { must: filters } } } }
    end
    elastic_hash = { query: query }
    elastic_hash[:sort] = options[:sort] if options[:sort]
    elastic_hash[:fields] = options[:fields] if options[:fields]
    elastic_hash[:size] = options[:size] if options[:size]
    elastic_hash[:from] = options[:from] if options[:from]
    if options[:aggregate]
      elastic_hash[:aggs] = Hash[options[:aggregate].map{ |k, v|
        # some aggregations are simple like
        #   { aggregate: { "colors.id": 12 } }
        if v.first[1].is_a?(Fixnum)
          [ k, { terms: { field: v.first[0], size: v.first[1] } } ]
        else
          # others are more complicated and are passed on verbatim
          [ k, v ]
        end
      }]
    end
    elastic_hash
  end

  def self.id_or_object(obj)
    if obj.kind_of?(ActiveRecord::Base) && obj.respond_to?(:id)
      obj.id
    else
      obj
    end
  end

  def self.place_filter(options={})
    return unless options && options.is_a?(Hash)
    return unless place = options[:place]
    { geo_shape: {
        _cache: true,
        private_geojson: {
          indexed_shape: {
            id: id_or_object(place),
            type: "place",
            index: Place.index_name,
            path: "geometry_geojson" } } } }
  end

  def self.envelope_filter(options={})
    return unless options && options.is_a?(Hash) && options[:envelope]
    # e.g. options = { envelope: { geojson: { nelat:X, nelng:Y... } } }
    field = options[:envelope].first[0]
    opts = options[:envelope].first[1]
    # if we are given a user, then we return matches against any of that
    # users observations' private coordinates. This is done with a gnarly
    # query which basically says:
    #   where public geom X OR ( obs.owner=user and private_geom X)
    if opts[:user] && opts[:user].is_a?(User)
      coords = opts.reject{ |k,v| k == :user }
      return { or: [
        envelope_filter({ envelope: { field => coords } }),
        { and: [
          { term: { "user.id": opts[:user].id } },
          envelope_filter({ envelope: { "private_#{field}": coords } }) ]}
      ]}
    end
    nelat = opts[:nelat]
    nelng = opts[:nelng]
    swlat = opts[:swlat]
    swlng = opts[:swlng]
    return unless nelat || nelng || swlat || swlng
    swlng = (swlng || -180).to_f
    swlat = (swlat || -90).to_f
    nelng = (nelng || 180).to_f
    nelat = (nelat || 90).to_f
    if nelng && swlng && nelng < swlng
      # the envelope crosses the dateline. Unfortunately, elasticsearch
      # doesn't handle this well and we need to split the envelope at
      # the dateline and do an OR query
      left = options.deep_dup
      right = options.deep_dup
      left[:envelope][field][:nelng] = 180
      right[:envelope][field][:swlng] = -180
      return { or: [
          envelope_filter(left),
          envelope_filter(right) ]}
    end
    { geo_shape: {
        field => {
          shape: {
            type: "envelope",
            coordinates: [
              [ swlng, swlat ],
              [ nelng, nelat ] ] } } } }
  end

  def self.point_geojson(lat, lon)
    return unless valid_latlon?(lat, lon)
    # notice the order of lon, lat which is standard for GeoJSON
    { type: "point", coordinates: [ lon, lat ] }
  end

  def self.point_latlon(lat, lon)
    return unless valid_latlon?(lat, lon)
    # notice the order of lat, lon which is used for ES geo_point
    "#{lat},#{lon}"
  end

  def self.valid_latlon?(lat, lon)
    return false unless lat.kind_of?(Numeric) && lon.kind_of?(Numeric)
    return false if lat < -90.0 || lat > 90.0
    return false if lon < -180.0 || lon > 180.0
    true
  end

  def self.geom_geojson(geom)
    return unless [ RGeo::Geos::CAPIMultiPolygonImpl,
                    RGeo::Geos::CAPIPointImpl ].include?(geom.class)
    RGeo::GeoJSON.encode(geom)
  end

  # used when indexing dates to enable queries like:
  # `show me all observations from April of any year`
  def self.date_details(datetime)
    return unless datetime
    return unless datetime.is_a?(Date) || datetime.is_a?(Time)
    { day: datetime.day,
      month: datetime.month,
      year: datetime.year,
      hour: datetime.respond_to?(:hour) ? datetime.hour : nil,
      week: datetime.strftime("%W").to_i + 1 }
  end

end
