import React from "react";
import _ from "lodash";
import DateHistogram from "./date_histogram";

const Observations = ( { data } ) => {
  return (
    <div className="Observations">
      <h2>{ I18n.t( "observations" ) }</h2>
      <DateHistogram
        series={ {
          month: {
            title: "Per Month",
            data: _.map( data.month_histogram.month, ( value, date ) => ( { date, value } ) )
          },
          week: {
            title: "Per Week",
            data: _.map( data.week_histogram.week, ( value, date ) => ( { date, value } ) ),
            color: "#74ac00"
          },
          day: {
            title: "Per Day",
            data: _.map( data.day_histogram.day, ( value, date ) => ( { date, value } ) ),
            color: "#aaaaaa"
          }
        } }
      />
    </div>
  );
};

Observations.propTypes = {
  data: React.PropTypes.object
};

export default Observations;
