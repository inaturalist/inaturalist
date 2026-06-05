# frozen_string_literal: true

module FormatHelper
  def time_until_in_words( time )
    seconds = ( time - Time.now ).to_i.abs
    minutes = ( seconds / 60.0 ).round
    hours = ( minutes / 60.0 ).round
    days = ( hours / 24.0 ).round
    months = ( days / 30.0 ).round
    years = ( days / 365.0 ).round

    scope = "datetime.distance_in_words"
    if seconds < 60
      I18n.t( "x_seconds", count: seconds, scope: scope )
    elsif minutes < 60
      I18n.t( "x_minutes", count: minutes, scope: scope )
    elsif hours < 24
      I18n.t( "x_hours", count: hours, scope: scope )
    elsif days < 30
      I18n.t( "x_days", count: days, scope: scope )
    elsif months < 12
      I18n.t( "x_months", count: months, scope: scope )
    else
      I18n.t( "x_years", count: years, scope: scope )
    end
  end
end
