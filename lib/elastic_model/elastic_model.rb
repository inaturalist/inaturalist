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
      if value.is_a? Array
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
    if options[:aggregate]
      elastic_hash[:aggs] = Hash[options[:aggregate].map{ |k, v|
        [ k, { terms: { field: v.first[0], size: v.first[1] } } ]
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
        geojson: {
          indexed_shape: {
            id: id_or_object(place),
            type: "place",
            index: "places",
            path: "geometry_geojson" } } } }
  end

  def self.envelope_filter(options={})
    return unless options && options.is_a?(Hash) && options[:envelope]
    nelat = options[:envelope][:nelat]
    nelng = options[:envelope][:nelng]
    swlat = options[:envelope][:swlat]
    swlng = options[:envelope][:swlng]
    return unless nelat || nelng || swlat || swlng
    { geo_shape: {
        geojson: {
          shape: {
            type: "envelope",
            coordinates: [
              [ swlng || -180, swlat || -90 ],
              [ nelng || 180, nelat || 90 ] ] } } } }
  end

  def self.result_to_will_paginate_collection(result)
    begin
      WillPaginate::Collection.create(result.current_page,
        result.per_page, result.total_entries) do |pager|
        pager.replace(result.records.to_a)
      end
    rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
      Rails.logger.error "[Error] Elasticsearch query failed: #{ e }"
      Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
      WillPaginate::Collection.new(1, 30, 0)
    end
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
      year: datetime.year }
  end

end
