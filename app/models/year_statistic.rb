class YearStatistic < ActiveRecord::Base
  belongs_to :user
  belongs_to :site

  def self.generate_for_year( year, options = {} )
    @year_statistic = YearStatistic.where( year: year ).where( "user_id IS NULL" )
    if options[:site]
      @year_statistic = @year_statistic.where( site_id: options[:site] )
    end
    @year_statistic = @year_statistic.first_or_create
    json = {
      observations: {
        quality_grade_counts: obervation_counts_by_quality_grade( year, options ),
        month_histogram: observations_histogram( year, options.merge( interval: "month" ) ),
        week_histogram: observations_histogram( year, options.merge( interval: "week" ) ),
        day_histogram: observations_histogram( year, options.merge( interval: "day" ) ),
        day_last_year_histogram: observations_histogram( year - 1, options.merge( interval: "day" ) ),
        popular: popular_observations( year, options )
      },
      identifications: {
        category_counts: identification_counts_by_category( year, options ),
        month_histogram: identifications_histogram( year, options.merge( interval: "month" ) ),
        week_histogram: identifications_histogram( year, options.merge( interval: "week" ) ),
        day_histogram: identifications_histogram( year, options.merge( interval: "day" ) )
      },
      taxa: {
        leaf_taxa_count: leaf_taxa_count( year, options ),
        iconic_taxa_counts: iconic_taxa_counts( year, options )
      }
    }
    @year_statistic.update_attributes( data: json )
  end

  def self.generate_for_site_year( site, year )
    generate_for_year( year, { site: site } )
  end

  def self.generate_for_user_year( user, year )
    user = user.is_a?( User ) ? user : User.find_by_id( user )
    return unless user
    @year_statistic = YearStatistic.where( year: year ).where( user_id: user ).first_or_create
    json = {
      observations: {
        quality_grade_counts: obervation_counts_by_quality_grade( year, user: user ),
        month_histogram: observations_histogram( year, user: user, interval: "month" ),
        week_histogram: observations_histogram( year, user: user, interval: "week" ),
        day_histogram: observations_histogram( year, user: user, interval: "day" ),
        day_last_year_histogram: observations_histogram( year - 1, user: user, interval: "day" ),
        popular: popular_observations( year, user: user )
      },
      identifications: {
        category_counts: identification_counts_by_category( year, user: user ), 
        month_histogram: identifications_histogram( year, user: user, interval: "month" ),
        week_histogram: identifications_histogram( year, user: user, interval: "week" ),
        day_histogram: identifications_histogram( year, user: user, interval: "day" )
      },
      taxa: {
        leaf_taxa_count: leaf_taxa_count( year, user: user ),
        iconic_taxa_counts: iconic_taxa_counts( year, user: user ),
        tree_taxa: tree_taxa( year, user: user )
      }
    }
    @year_statistic.update_attributes( data: json )
  end

  def self.regenerate_existing
    YearStatistic.find_each do |ys|
      if ys.user
        YearStatistic.generate_for_user_year( ys.user, ys.year )
      else
        YearStatistic.generate_for_year( ys.year )
      end
    end
  end

  def self.tree_taxa( year, options = {} )
    params = { year: year }
    if user = options[:user]
      params[:user_id] = user.id
    end
    if site = options[:site]
      params[:site_id] = site.id
    end
    JSON.parse( INatAPIService.get_json("/observations/tree_taxa", params ) )["results"] rescue nil
  end

  def self.observations_histogram( year, options = {} )
    params = {
      d1: "#{year}-01-01",
      d2: "#{year}-12-31",
      interval: options[:interval] || "day",
      quality_grade: options[:quality_grade] || "research,needs_id"
    }
    if user = options[:user]
      params[:user_id] = user.id
    end
    if site = options[:site]
      params[:site_id] = site.id
    end
    JSON.parse( INatAPIService.get_json("/observations/histogram", params ) )["results"][params[:interval]]
  end

  def self.identifications_histogram( year, options = {} )
    interval = options[:interval] || "day"
    es_params = {
      size: 0,
      filters: [
        { terms: { "created_at_details.year": [year] } }
      ],
      aggregate: {
        histogram: {
          date_histogram: {
            field: "created_at_details.date",
            interval: interval,
            format: "yyyy-MM-dd"
          }
        }
      }
    }
    if options[:user]
      es_params[:filters] << { terms: { "user.id": [options[:user].id] } }
    end
    if site = options[:site]
      es_params[:filters] << { terms: { "user.site_id": [site.id] } }
    end
    histogram = {}
    Identification.elastic_search( es_params ).response.aggregations.histogram.buckets.each {|b|
      histogram[b.key_as_string] = b.doc_count
    }
    histogram
  end

  def self.identification_counts_by_category( year, options = {} )
    es_params = {
      size: 0,
      filters: [
        { terms: { "created_at_details.year": [year] } },
        { terms: { "own_observation": [false] } }
      ],
      aggregate: {
        categories: { terms: { field: "category" } }
      }
    }
    if options[:user]
      es_params[:filters] << { terms: { "user.id": [options[:user].id] } }
    end
    if site = options[:site]
      es_params[:filters] << { terms: { "user.site_id": [site.id] } }
    end
    Identification.elastic_search( es_params ).response.aggregations.categories.buckets.inject({}) do |memo, bucket|
      memo[bucket["key"]] = bucket.doc_count
      memo
    end
  end

  def self.obervation_counts_by_quality_grade( year, options = {} )
    params = { year: year }
    params[:user_id] = options[:user].id if options[:user]
    if site = options[:site]
      params[:site_id] = site.id
    end
    elastic_params = Observation.params_to_elastic_query( params )
    Observation.elastic_search( elastic_params.merge(
      size: 0,
      aggregate: {
        quality_grades: { terms: { field: "quality_grade" } }
      }
    ) ).response.aggregations.quality_grades.buckets.inject({}) do |memo, bucket|
      memo[bucket["key"]] = bucket.doc_count
      memo
    end
  end

  def self.leaf_taxa_count( year, options = {} )
    params = { year: year, verifiable: true }
    params[:user_id] = options[:user].id if options[:user]
    if site = options[:site]
      params[:site_id] = site.id
    end
    Observation.elastic_taxon_leaf_counts( Observation.params_to_elastic_query( params ) ).size
  end

  def self.iconic_taxa_counts( year, options = {} )
    params = { year: year, verifiable: true }
    params[:user_id] = options[:user].id if options[:user]
    if site = options[:site]
      params[:site_id] = site.id
    end
    elastic_params = Observation.params_to_elastic_query( params )
    Observation.elastic_search( elastic_params.merge(
      size: 0,
      aggregate: {
        iconic_taxa: { terms: { field: "taxon.iconic_taxon_id" } }
      }
    ) ).response.aggregations.iconic_taxa.buckets.inject({}) do |memo, bucket|
      key = Taxon::ICONIC_TAXA_BY_ID[bucket["key"].to_i].try(:name)
      memo[key] = bucket.doc_count
      memo
    end
  end

  def self.popular_observations( year, options = {} )
    puts "options: #{options}"
    params = options.merge( year: year, has_photos: true, verifiable: true )
    if user = params.delete(:user)
      params[:user_id] = user.id
    end
    if site = params.delete(:site)
      params[:site_id] = site.id
    end
    puts "params: #{params}"
    es_params = Observation.params_to_elastic_query( params )
    puts "es_params: #{es_params}"
    es_params_with_sort = es_params.merge(
      sort: {
        "_script": {
          "type": "number",
          "script": {
            "lang": "painless",
            "inline": "doc['cached_votes_total'].value + doc['comments_count'].value"
          },
          "order": "desc"
        }
      }
    )
    r = Observation.elastic_search( es_params_with_sort ).per_page( 200 ).response
    ids = r.hits.hits.map{|h| h._source.id }
    api_params = {
      id: ids,
      per_page: 200
    }
    if user
      if place = user.place || user.site.try(:place)
        api_params[:preferred_place_id] = place.id
      end
      if locale = user.locale || user.site.try(:locale)
        api_params[:locale] = locale
      end
    elsif site
      if place = site.place
        api_params[:preferred_place_id] = place.id
      end
      if locale = site.locale
        api_params[:locale] = locale
      end
    end
    return [] if ids.blank?
      
    JSON.
        parse( INatAPIService.get_json( "/observations", api_params ) )["results"].
        sort_by{|o| (o["comments_count"].to_i + o["cached_votes_total"].to_i ) * -1 }.
        each_with_index.map do |o,i|
      if i < 10
        o.select{|k,v| %w(id taxon community_taxon user photos comments_count cached_votes_total).include?( k ) }
      else
        {
          "id": o["id"],
          "photos": [o["photos"][0].select{|k,v| %w(url original_dimensions).include?( k ) }]
        }
      end
    end
  end

end
