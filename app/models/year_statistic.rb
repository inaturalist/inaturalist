class YearStatistic < ActiveRecord::Base
  belongs_to :user

  def self.generate_for_year( year )
    @year_statistic = YearStatistic.where( year: year ).where( "user_id IS NULL" ).first_or_create
    json = {
      observations: {
        quality_grade_counts: obervation_counts_by_quality_grade( year ),
        month_histogram: observations_histogram( year, interval: "month" ),
        week_histogram: observations_histogram( year, interval: "week" ),
        day_histogram: observations_histogram( year, interval: "day" ),
        day_last_year_histogram: observations_histogram( year - 1, interval: "day" )
      },
      identifications: {
        category_counts: identification_counts_by_category( year ),
        month_histogram: identifications_histogram( year, interval: "month" ),
        week_histogram: identifications_histogram( year, interval: "week" ),
        day_histogram: identifications_histogram( year, interval: "day" )
      },
      taxa: {
        leaf_taxa_count: leaf_taxa_count( year ),
        iconic_taxa_counts: iconic_taxa_counts( year )
      }
    }
    @year_statistic.update_attributes( data: json )
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
        day_last_year_histogram: observations_histogram( year - 1, user: user, interval: "day" )
      },
      identifications: {
        category_counts: identification_counts_by_category( year, user: user ), 
        month_histogram: identifications_histogram( year, user: user, interval: "month" ),
        week_histogram: identifications_histogram( year, user: user, interval: "week" ),
        day_histogram: identifications_histogram( year, user: user, interval: "day" )
      },
      taxa: {
        leaf_taxa_count: leaf_taxa_count( year, user: user ),
        iconic_taxa_counts: iconic_taxa_counts( year, user: user )
      }
    }
    @year_statistic.update_attributes( data: json )
  end

  def self.observations_histogram( year, options = {} )
    options[:d1] = "#{year}-01-01"
    options[:d2] = "#{year}-12-31"
    options[:interval] ||= "day"
    options[:quality_grade] ||= "research,needs_id"
    if user = options.delete(:user)
      options[:user_id] = user.id
    end
    JSON.parse( INatAPIService.get_json("/observations/histogram", options ) )["results"][options[:interval]]
  end

  def self.identifications_histogram( year, options = {} )
    options[:interval] ||= "day"
    es_params = {
      size: 0,
      filters: [
        { terms: { "created_at_details.year": [year] } }
      ],
      aggregate: {
        histogram: {
          date_histogram: {
            field: "created_at_details.date",
            interval: options[:interval],
            format: "yyyy-MM-dd"
          }
        }
      }
    }
    if options[:user]
      es_params[:filters] << { terms: { "user.id": [options[:user].id] } }
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
    Identification.elastic_search( es_params ).response.aggregations.categories.buckets.inject({}) do |memo, bucket|
      memo[bucket["key"]] = bucket.doc_count
      memo
    end
  end

  def self.obervation_counts_by_quality_grade( year, options = {} )
    params = { year: year }
    params[:user_id] = options[:user].id if options[:user]
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
    Observation.elastic_taxon_leaf_counts( Observation.params_to_elastic_query( params ) ).size
  end

  def self.iconic_taxa_counts( year, options = {} )
    params = { year: year, verifiable: true }
    params[:user_id] = options[:user].id if options[:user]
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

end
