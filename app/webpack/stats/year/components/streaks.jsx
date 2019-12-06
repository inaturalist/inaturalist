import React from "react";
import PropTypes from "prop-types";
import { scaleTime } from "d3";
import moment from "moment";
import UserImage from "../../../shared/components/user_image";
import UserLink from "../../../shared/components/user_link";

const Streaks = ( {
  data,
  year,
  hideUsers
} ) => {
  const scale = scaleTime( )
    .domain( [new Date( `${year}-01-01` ), new Date( `${year}-12-31` )] )
    .range( [0, 1.0] );
  const ticks = scale.ticks();
  const tickWidth = scale( ticks[1] ) - scale( ticks[0] );
  return (
    <div className="Streaks">
      <h3><span>{ I18n.t( "views.stats.year.streaks" ) }</span></h3>
      <div className="rows">
        <div
          className="ticks streak"
          key="streaks-ticks"
        >
          { !hideUsers && <div className="user" /> }
          <div className="background">
            { scale.ticks( ).map( ( tick, i ) => (
              <div
                className={`tick ${i % 2 === 0 ? "alt" : ""}`}
                key={`streaks-ticks-${tick}`}
                style={{
                  left: `${scale( new Date( tick ) ) * 100}%`,
                  height: 35 * data.length + 35,
                  width: `${tickWidth * 100}%`
                }}
              >
                { moment( tick ).format( "MMM" ) }
              </div>
            ) ) }
          </div>
        </div>
        { data.map( streak => {
          const x1 = scale( new Date( streak.start ) );
          const x2 = scale( new Date( streak.stop ) );
          const width = x2 - x1;
          const user = {
            login: streak.login,
            id: streak.user_id,
            icon_url: streak.icon_url
          };
          const xDays = I18n.t( "datetime.distance_in_words.x_days", { count: I18n.toNumber( streak.days, { precision: 0 } ) } );
          const d1 = moment( streak.start ).format( "ll" );
          const d2 = moment( streak.stop ).format( "ll" );
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
                  href={`/observations?user_id=${streak.login}&d1=${streak.start}&d2=${streak.stop}`}
                  style={{
                    left: `${x1 * 100}%`,
                    width: `${width * 100}%`
                  }}
                  title={`${I18n.t( "date_to_date", { d1, d2 } )} • ${xDays}`}
                >
                  <span className="days">
                    { xDays }
                  </span>
                </a>
              </div>
            </div>
          );
        } ) }
      </div>
    </div>
  );
};

Streaks.propTypes = {
  // site: PropTypes.object,
  // user: PropTypes.object,
  year: PropTypes.number.isRequired,
  data: PropTypes.array.isRequired,
  hideUsers: PropTypes.boolean
};

export default Streaks;
