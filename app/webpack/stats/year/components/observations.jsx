import React from "react";
import _ from "lodash";
import moment from "moment";
import DateHistogram from "./date_histogram";

const Observations = ( { data } ) => {
  const series = {};
  if ( data.month_histogram ) {
    series.month = {
      title: "Per Month",
      data: _.map( data.month_histogram.month, ( value, date ) => ( { date, value } ) ),
      style: "bar",
      color: "rgba( 80%, 80%, 80%, 0.5 )",
      label: d => `<strong>${moment( d.date ).format( "MMMM" )}</strong>: ${d.value}`
    };
  }
  if ( data.week_histogram ) {
    series.week = {
      title: "Per Week",
      data: _.map( data.week_histogram.week, ( value, date ) => ( { date, value } ) ),
      color: "#a8cc09",
      style: "bar",
      label: d => `<strong>Week of ${moment( d.date ).format( "LL" )}</strong>: ${d.value}`
    };
  }
  if ( data.day_histogram ) {
    series.day = {
      title: "Per Day",
      data: _.map( data.day_histogram.day, ( value, date ) => ( { date, value } ) ),
      color: "#74ac00"
    };
  }
  return (
    <div className="Observations">
      <h2>{ I18n.t( "observations" ) }</h2>
      <DateHistogram series={ series } />
    </div>
  );
};

Observations.propTypes = {
  data: React.PropTypes.object
};

export default Observations;
