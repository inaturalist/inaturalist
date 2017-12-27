import React from "react";
import { Row, Col } from "react-bootstrap";
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
      title: I18n.t( "per_month" ),
      data: _.map( data.month_histogram, ( value, date ) => ( { date, value } ) ),
      style: "bar",
      color: grayColor,
      label: d => `<strong>${moment( d.date ).format( "MMMM" )}</strong>: ${d.value}`
    };
  }
  if ( data.week_histogram ) {
    series.week = {
      title: I18n.t( "per_week" ),
      data: _.map( data.week_histogram, ( value, date ) => ( { date, value } ) ),
      color: "rgba( 168, 204, 9, 0.2 )",
      style: "bar",
      label: d => `<strong>${I18n.t( "week_of_date", { date: moment( d.date ).format( "LL" ) } )}</strong>: ${d.value}`
    };
  }
  if ( data.day_histogram ) {
    series.day = {
      title: I18n.t( "per_day" ),
      data: _.map( data.day_histogram, ( value, date ) => ( { date, value } ) ),
      color: "#74ac00"
    };
  }
  const comparisonSeries = {};
  if ( data.day_histogram && data.day_last_year_histogram ) {
    comparisonSeries.this_year = {
      title: I18n.t( "this_year" ),
      data: _.map( data.day_histogram, ( value, date ) => ( { date, value } ) ),
      color: "#74ac00"
    };
    comparisonSeries.last_year = {
      title: I18n.t( "last_year" ),
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
        { _.map( _.chunk( data.popular.slice( 0, 8 ), 4 ), ( chunk, i ) => (
          <Row key={ `popular-obs-chunk-${i}` }>
            { chunk.map( o => (
              <Col xs={3} key={ `popular-obs-${o.id}` }>
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
              </Col>
            ) ) }
          </Row>
        ) ) }
      </div>
    );
  }
  moment.locale( I18n.locale );
  return (
    <div className="Observations">
      <h3><span>{ I18n.t( "verifiable_observations_by_observation_date" ) }</span></h3>
      <DateHistogram
        series={ series }
        tickFormatBottom={ d => moment( d ).format( "MMM D" ) }
        onClick={ d => {
          let url = "/observations?place_id=any&verifiable=true";
          if ( d.seriesName === "month" ) {
            url += `&year=${d.date.getFullYear( )}&month=${d.date.getMonth() + 1}`;
          } else if ( d.seriesName === "week" ) {
            const d1 = moment( d.date ).format( "YYYY-MM-DD" );
            const d2 = moment( d.date ).add( 8, "days" ).format( "YYYY-MM-DD" );
            url += `&d1=${d1}&d2=${d2}`;
          } else {
            url += `&on=${d.date.getFullYear( )}-${d.date.getMonth( ) + 1}-${d.date.getDate( )}`;
          }
          if ( user ) {
            url += `&user_id=${user.login}`;
          }
          window.open( url, "_blank" );
        } }
      />
      <h3><span>{ I18n.t( "observations_this_year_vs_last_year" ) }</span></h3>
      <DateHistogram
        series={ comparisonSeries }
        tickFormatBottom={ d => moment( d ).format( "MMM D" ) }
        onClick={ d => {
          let url = "/observations?place_id=any&verifiable=true";
          if ( d.seriesName === "last_year" ) {
            url += `&on=${d.date.getFullYear( ) - 1}-${d.date.getMonth( ) + 1}-${d.date.getDate( )}`;
          } else {
            url += `&on=${d.date.getFullYear( )}-${d.date.getMonth( ) + 1}-${d.date.getDate( )}`;
          }
          if ( user ) {
            url += `&user_id=${user.login}`;
          }
          window.open( url, "_blank" );
        } }
      />
      { user && ( <TorqueMap user={ user } year={ year } interval={ user ? "weekly" : "monthly" } /> ) }
      <h3><span>{ I18n.t( "most_comments_and_faves" ) }</span></h3>
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
