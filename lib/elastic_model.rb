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

  def self.id_or_object(obj)
    if obj.kind_of?(ActiveRecord::Base) && obj.respond_to?(:id)
      obj.id
    else
      obj
    end
  end

  def self.place_filter(options={})
    return unless options && options.is_a?(Hash) &&
      options[:filter] && options[:filter][:place]
    { geo_shape: {
        geojson: {
          indexed_shape: {
            id: id_or_object(options[:filter][:place]),
            type: "place",
            index: "places",
            path: "geometry_geojson" } } } }
  end

  def self.envelope_filter(options={})
    return unless options && options.is_a?(Hash) && options[:filter]
    filter = options[:filter]
    return unless filter[:nelat] || filter[:nelng] || filter[:swlat] || filter[:swlng]
    { geo_shape: {
        geojson: {
          shape: {
            type: "envelope",
            coordinates: [
              [ filter[:swlng] || -180, filter[:swlat] || -90 ],
              [ filter[:nelng] || 180, filter[:nelat] || 90 ] ] } } } }
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

end

Dir["#{File.dirname(__FILE__)}/elastic_model/**/*.rb"].each { |f| load(f) }
