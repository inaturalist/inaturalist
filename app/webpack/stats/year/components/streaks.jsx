import React from "react";
import PropTypes from "prop-types";
import {
  scaleTime,
  scaleLog,
  scaleLinear,
  min as d3min,
  max as d3max,
  timeMonth,
  timeFormatLocale,
  timeYear,
  interpolateWarm
} from "d3";
import moment from "moment";
import _ from "lodash";
import UserImage from "../../../shared/components/user_image";
import UserLink from "../../../shared/components/user_link";

const Streaks = ( {
  data,
  year,
  hideUsers
} ) => {
  let startYear = year;
  if ( _.filter( data, streak => streak.days > 300 ).length / data.length > 0.5 ) {
    const years = _.uniq( _.flatten( _.map(
      data,
      streak => [moment( streak.start ).year( ), moment( streak.stop ).year( )]
    ) ) ).sort( );
    if ( years.length <= 2 ) {
      startYear = years[0];
    } else {
      startYear = years[Math.round( years.length / 2 )];
    }
  }
  const multiYear = startYear < year;
  const dates = [new Date( `${startYear}-01-01` ), new Date( `${year}-12-31` )];
  const scale = scaleTime( )
    .domain( dates )
    .range( [0, 1.0] );
  let ticks = scale.ticks( timeMonth.every( 1 ) );
  let dateFormat = ticks.length > 12 ? "MMM 'YY" : "MMM";
  if ( ticks.length > 24 ) {
    ticks = scale.ticks( timeYear.every( 1 ) );
    dateFormat = "YYYY";
  }
  const days = data.map( d => d.days );
  const dayScale = scaleLog( )
    .domain( [d3min( days ), d3max( days )] )
    .range( [0, 1] );
  const dayColorScale = scaleLinear( )
    .domain( [0, 1] )
    .range( [0, 0.8] );
  const dayScaleTicks = dayScale.ticks( );
  dayScaleTicks.push( d3max( days ) );
  const d3Locale = timeFormatLocale( {
    datetime: I18n.t( "time.formats.long" ),
    date: I18n.t( "date.formats.long" ),
    time: I18n.t( "time.formats.hours" ),
    periods: [I18n.t( "time.am" ), I18n.t( "time.pm" )],
    days: I18n.t( "date.day_names" ),
    shortDays: I18n.t( "date.abbr_day_names" ),
    months: _.compact( I18n.t( "date.month_names" ) ).map( n => n.toString( ) ),
    shortMonths: _.compact( I18n.t( "date.abbr_month_names" ) ).map( n => n.toString( ) )
  } );
  const shortDate = d3Locale.format( I18n.t( "date.formats.compact" ) );
  return (
    <div className={`Streaks ${multiYear ? "multiyear" : ""}`}>
      <h3>
        <a name="streaks" href="#streaks">
          <span>{ I18n.t( "views.stats.year.observation_streaks" ) }</span>
        </a>
      </h3>
      <p className="text-muted">
        { I18n.t( "views.stats.year.observation_streaks_desc2" ) }
      </p>
      <div className="rows">
        <div
          className="ticks streak"
          key="streaks-ticks"
        >
          { !hideUsers && <div className="user" /> }
          <div className="background">
            { ticks.map( ( tick, i ) => {
              const tickDate = new Date( tick );
              const left = i === 0
                ? 0
                : Math.max( 0, scale( tickDate ) );
              const tickWidth = i === ticks.length - 1
                ? 1 - scale( tickDate )
                : scale( ticks[i + 1] ) - scale( tickDate );
              return (
                <div
                  className={`tick ${i % 2 === 0 ? "alt" : ""}`}
                  key={`streaks-ticks-${tick}`}
                  style={{
                    left: `${left * 100}%`,
                    height: 35.6 * data.length + 35.6,
                    width: `${tickWidth * 100}%`
                  }}
                >
                  { moment( tick ).format( dateFormat ) }
                </div>
              );
            } ) }
          </div>
        </div>
        { data.map( streak => {
          const x1 = Math.max( 0, scale( new Date( streak.start ) ) );
          const x2 = scale( new Date( streak.stop ) );
          const width = Math.min( 1, x2 - x1 );
          const user = {
            login: streak.login,
            id: streak.user_id,
            icon_url: streak.icon_url
          };
          const xDays = I18n.t( "datetime.distance_in_words.x_days", { count: I18n.toNumber( streak.days, { precision: 0 } ) } );
          const streakStartedBeforeStartYear = moment( streak.start ) < moment( `${startYear}-01-01` );
          const d1 = streakStartedBeforeStartYear
            ? moment( streak.start ).format( "ll" )
            : shortDate( moment( streak.start ) );
          const d2 = shortDate( moment( streak.stop ) );
          return (
            <div
              key={`streaks-${streak.login}-${streak.start}`}
              className="streak"
            >
              { !hideUsers && (
                <div className="user">
                  <UserImage user={user} />
                  <UserLink user={user} />
                </div>
              ) }
              <div className="background">
                <a
                  className="datum"
                  href={`/observations?user_id=${streak.login}&d1=${streak.start}&d2=${streak.stop}&place_id=any&verifiable=true`}
                  style={{
                    left: `${Math.max( 0, x1 * 100 )}%`,
                    width: `${width * 100}%`,
                    backgroundColor: interpolateWarm( dayColorScale( dayScale( streak.days ) ) )
                  }}
                  title={`${I18n.t( "date_to_date", { d1, d2 } )} • ${xDays}`}
                >
                  { streakStartedBeforeStartYear && (
                    <span
                      className="triangle"
                      style={{
                        borderRightColor: interpolateWarm(
                          dayColorScale( dayScale( streak.days ) )
                        )
                      }}
                    />
                  ) }
                  { width > 0.25 && <span className="start">{ d1 }</span> }
                  { width > 0.05 && <span className="days">{ xDays }</span> }
                  { width > 0.25 && <span className="stop">{ d2 }</span> }
                </a>
              </div>
            </div>
          );
        } ) }
      </div>
      { data.length > 1 && (
        <div className="legend">
          <p className="text-muted">
            { I18n.t( "views.stats.year.observation_streaks_color_desc" ) }
          </p>
          <div style={{ width: "100%" }}>
            <div className="ticks" style={{ position: "relative", height: 50 }}>
              { dayScaleTicks.map( ( tick, i ) => {
                const v = dayScale( tick );
                const left = i === 0 ? 0 : dayScale( dayScaleTicks[i - 1] );
                const width = i === 0 ? v : v - dayScale( dayScaleTicks[i - 1] );
                const cssGradient = `
                  linear-gradient(
                    to right,
                    ${interpolateWarm( dayColorScale( v - width ) )},
                    ${interpolateWarm( dayColorScale( v ) )}
                  )
                `;
                const tickDays = I18n.t( "datetime.distance_in_words.x_days", { count: I18n.toNumber( tick, { precision: 0 } ) } );
                return (
                  <div
                    className="tick"
                    key={`color-tick-${tick}`}
                    style={{
                      left: `${left * 100}%`,
                      width: `${width * 100}%`
                    }}
                  >
                    <div className="line" alt={tickDays} title={tickDays}>
                      { i >= dayScaleTicks.length - 1 ? tickDays : tick }
                    </div>
                    <div
                      className="bar"
                      style={{
                        backgroundImage: cssGradient
                      }}
                    />
                  </div>
                );
              } ) }
            </div>
          </div>
        </div>
      ) }
    </div>
  );
};

Streaks.propTypes = {
  year: PropTypes.number.isRequired,
  data: PropTypes.array.isRequired,
  hideUsers: PropTypes.bool
};

export default Streaks;
