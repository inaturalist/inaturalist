import React from "react";
import _ from "lodash";
import moment from "moment";
import inatjs from "inaturalistjs";
import ObservationsGridItem from "../../../shared/components/observations_grid_item";
import DateHistogram from "./date_histogram";
import TorqueMap from "./torque_map";

const Observations = ( { data, user, year } ) => {
  const series = {};
  const grayColor = "rgba( 40%, 40%, 40%, 0.5 )";
  if ( data.month_histogram ) {
    series.month = {
      title: "Per Month",
      data: _.map( data.month_histogram, ( value, date ) => ( { date, value } ) ),
      style: "bar",
      color: grayColor,
      label: d => `<strong>${moment( d.date ).format( "MMMM" )}</strong>: ${d.value}`
    };
  }
  if ( data.week_histogram ) {
    series.week = {
      title: "Per Week",
      data: _.map( data.week_histogram, ( value, date ) => ( { date, value } ) ),
      color: "rgba( 168, 204, 9, 0.2 )",
      style: "bar",
      label: d => `<strong>Week of ${moment( d.date ).format( "LL" )}</strong>: ${d.value}`
    };
  }
  if ( data.day_histogram ) {
    series.day = {
      title: "Per Day",
      data: _.map( data.day_histogram, ( value, date ) => ( { date, value } ) ),
      color: "#74ac00"
    };
  }
  const comparisonSeries = {};
  if ( data.day_histogram && data.day_last_year_histogram ) {
    comparisonSeries.this_year = {
      title: "This Year",
      data: _.map( data.day_histogram, ( value, date ) => ( { date, value } ) ),
      color: "#74ac00"
    };
    comparisonSeries.last_year = {
      title: "Last Year",
      data: _.map( data.day_last_year_histogram, ( value, date ) => {
        const lastYear = parseInt( date.match( /\d{4}/ )[0], 0 );
        const newYear = lastYear + 1;
        const newDate = date.replace( lastYear, newYear );
        return { date: newDate, value };
      } ),
      color: grayColor
    };
  }
  let popular;
  if ( data.popular && data.popular.length > 0 ) {
    popular = (
      <div className={ `popular ${user ? "for-user" : ""}` }>
        { data.popular.slice( 0, 5 ).map( o => (
          <ObservationsGridItem
            observation={ new inatjs.Observation( o ) }
            controls={
              <div>
                <span className="activity">
                  <span className="stat">
                    <i className="icon-chatbubble"></i> { o.comments_count }
                  </span>
                  <span className="stat">
                    <i className="fa fa-star"></i> { o.cached_votes_total }
                  </span>
                </span>
                <time
                  className="time pull-right"
                  dateTime={ o.created_at }
                  title={ moment( o.observed_on ).format( "LLL" ) }
                >
                  { moment( o.observed_on ).format( "YY MMM" ) }
                </time>
              </div>
            }
          />
        ) ) }
      </div>
    );
  }
  return (
    <div className="Observations">
      <h3><span>Verifiable Observations By Observation Date</span></h3>
      <DateHistogram series={ series } />
      <h3><span>Observations This Year vs. Last Year</span></h3>
      <DateHistogram series={ comparisonSeries } />
      { user && ( <TorqueMap user={ user } year={ year } interval={ user ? "weekly" : "monthly" } /> ) }
      <h3><span>Most Comments & Faves</span></h3>
      { popular }
    </div>
  );
};

Observations.propTypes = {
  user: React.PropTypes.object,
  year: React.PropTypes.number,
  data: React.PropTypes.object
};

export default Observations;
