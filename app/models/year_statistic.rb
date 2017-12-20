class YearStatistic < ActiveRecord::Base
  belongs_to :user

  def self.generate_for_year( year )
    @year_statistic = YearStatistic.where( year: year ).where( "user_id IS NULL" ).first_or_create
    json = {
      observations: {
        month_histogram: observations_histogram( year, interval: "month" ),
        week_histogram: observations_histogram( year, interval: "week" ),
        day_histogram: observations_histogram( year, interval: "day" )
      },
      identifications: {
        month_histogram: identifications_histogram( year, interval: "month" ),
        week_histogram: identifications_histogram( year, interval: "week" ),
        day_histogram: identifications_histogram( year, interval: "day" )
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
        month_histogram: observations_histogram( year, user: user, interval: "month" ),
        week_histogram: observations_histogram( year, user: user, interval: "week" ),
        day_histogram: observations_histogram( year, user: user, interval: "day" ),
      },
      identifications: {
        month_histogram: identifications_histogram( year, user: user, interval: "month" ),
        week_histogram: identifications_histogram( year, user: user, interval: "week" ),
        day_histogram: identifications_histogram( year, user: user, interval: "day" )
      }
    }
    @year_statistic.update_attributes( data: json )
  end

  def self.observations_histogram( year, options = {} )
    options[:year] = year
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
end
