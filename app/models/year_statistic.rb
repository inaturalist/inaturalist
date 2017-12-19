class YearStatistic < ActiveRecord::Base
  belongs_to :user

  def self.generate_for_year( year )
    @year_statistic = YearStatistic.where( year: year ).where( "user_id IS NULL" ).first_or_create
    json = {
      observations: {
        week_histogram: JSON.parse( INatAPIService.get_json("/observations/histogram", { year: year, quality_grade: "research,needs_id", interval: "week" } ) )["results"],
        day_histogram: JSON.parse( INatAPIService.get_json("/observations/histogram", { year: year, quality_grade: "research,needs_id", interval: "day" } ) )["results"]
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
        week_histogram: JSON.parse( INatAPIService.get_json("/observations/histogram", { user_id: user.id, year: year, quality_grade: "research,needs_id", interval: "week" } ) )["results"],
        day_histogram: JSON.parse( INatAPIService.get_json("/observations/histogram", { user_id: user.id, year: year, quality_grade: "research,needs_id", interval: "day" } ) )["results"]
      }
    }
    @year_statistic.update_attributes( data: json )
  end
end
