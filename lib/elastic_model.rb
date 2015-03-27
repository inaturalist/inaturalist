module ElasticModel

  ASCII_SNOWBALL_ANALYZER = {
    ascii_snowball_analyzer: {
      tokenizer: "standard",
      filter: [ "standard", "lowercase", "asciifolding", "stop", "snowball" ]
    }
  }
  AUTOCOMPLETE_ANALYZER = {
    autocomplete_analyzer: {
      tokenizer: "standard",
      filter: [ "standard", "lowercase", "asciifolding", "stop", "edge_ngram_filter" ]
    }
  }
  KEYWORD_AUTOCOMPLETE_ANALYZER = {
    keyword_autocomplete_analyzer: {
      tokenizer: "keyword",
      filter: [ "standard", "lowercase", "asciifolding", "stop", "edge_ngram_filter" ]
    }
  }
  KEYWORD_ANALYZER = {
    keyword_analyzer: {
      tokenizer: "keyword",
      filter: [ "standard", "lowercase", "asciifolding" ]
    }
  }
  WHITESPACE_ANALYZER = {
    whitespace_analyzer: {
      tokenizer: "whitespace",
      filter: [ "lowercase", "asciifolding" ]
    }
  }
  EDGE_NGRAM_FILTER =  {
    edge_ngram_filter: {
      type: "edgeNGram",
      min_gram: 2,
      max_gram: 15
    }
  }

  ANALYSIS = {
    analyzer: [
      ASCII_SNOWBALL_ANALYZER,
      AUTOCOMPLETE_ANALYZER,
      KEYWORD_AUTOCOMPLETE_ANALYZER,
      KEYWORD_ANALYZER,
      WHITESPACE_ANALYZER
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
    unless filters.blank?
      query = {
        filtered: {
          query: query,
          filter: {
            bool: { must: filters } } } }
    end
    elastic_hash = { query: query }
    if options[:sort]
      elastic_hash[:sort] = options[:sort]
    end
    if options[:fields]
      elastic_hash[:fields] = options[:fields]
    end
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
    WillPaginate::Collection.create(result.current_page,
      result.per_page, result.total_entries) do |pager|
      pager.replace(result.records.to_a)
    end
  end

  def self.point_geojson(lat, lon)
    return unless valid_latlon?(lat, lon)
    { type: "point", coordinates: [ lon, lat ] }
  end

  def self.point_latlon(lat, lon)
    return unless valid_latlon?(lat, lon)
    "#{lat},#{lon}"
  end

  def self.valid_latlon?(lat, lon)
    return false unless lat.kind_of?(Numeric) && lon.kind_of?(Numeric)
    return false if lat < -90.0 || lat > 90.0
    return false if lon < -180.0 || lon > 180.0
    true
  end

  def self.geom_geojson(geom)
    unless [ RGeo::Geos::CAPIMultiPolygonImpl, RGeo::Geos::CAPIPointImpl ].include?(geom.class)
      return
    end
    RGeo::GeoJSON.encode(geom)
  end

  def self.date_details(datetime)
    return unless datetime
    return unless datetime.is_a?(Date) || datetime.is_a?(Time)
    { day: datetime.day,
      month: datetime.month,
      year: datetime.year }
  end

end

Dir["#{File.dirname(__FILE__)}/elastic_model/**/*.rb"].each { |f| load(f) }
