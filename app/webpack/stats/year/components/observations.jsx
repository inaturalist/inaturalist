import React from "react";
import _ from "lodash";
import Histogram from "./histogram";

const Observations = ( { data } ) => {
  const daysX = ["daysX"].concat( _.keys( data.day_histogram.day ) );
  const days = ["days"].concat( _.values( data.day_histogram.day ) );
  const weeksX = ["weeksX"].concat( _.keys( data.week_histogram.week ) );
  const weeks = ["weeks"].concat( _.values( data.week_histogram.week ) );
  return (
    <div className="Observations">
      <h2>{ I18n.t( "observations" ) }</h2>
      <Histogram
        columns={ [daysX, weeksX, days, weeks] }
        config={ {
          data: {
            xs: {
              weeks: "weeksX",
              days: "daysX"
            }
          },
          axis: {
            x: {
              type: "timeseries"
            }
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
