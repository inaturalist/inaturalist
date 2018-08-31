import React from "react";
import PropTypes from "prop-types";
import { scaleOrdinal, schemeCategory10, timeFormat, extent, isoParse } from "d3";
import _ from "lodash";
import DateHistogram from "../../../stats/year/components/date_histogram";

const HistoryComparison = ( {
  historyLayout,
  historyInterval,
  setHistoryLayout,
  histories,
  queries,
  setHistoryInterval
} ) => {
  let charts;
  const colorScale = scaleOrdinal( schemeCategory10 );
  if ( histories.length === queries.length ) {
    let dateLabeler;
    if ( historyInterval === "hour" ) {
      const hourFormat = timeFormat( "%H:%M" );
      dateLabeler = d => `<strong>${hourFormat( d.date )}</strong>: ${d.value}`;
    }
    if ( historyLayout === "combined" ) {
      const series = {};
      _.forEach( queries, ( query, i ) => {
        series[query.name] = {
          title: query.name,
          data: _.map( histories[i], ( value, date ) => ( { date, value } ) ),
          color: colorScale( query.params ),
          label: dateLabeler
        };
      } );
      charts = (
        <DateHistogram
          series={ series }
        />
      );
    } else {
      const allDates = _.flatten( _.map( histories, history => _.keys( history ) ) ).map( isoParse );
      const allValues = _.flatten( _.map( histories, history => _.values( history ) ) );
      const xExtent = extent( allDates );
      const yExtent = extent( allValues );
      charts = queries.map( ( query, i ) => (
        <DateHistogram
          key={ `DateHistogram-${query.params}-${i}-${historyLayout}` }
          series={ {
            [query.name]: {
              title: query.name,
              data: _.map( histories[i], ( value, date ) => ( { date, value } ) ),
              color: colorScale( query.params ),
              label: dateLabeler
            }
          } }
          xExtent={ xExtent }
          yExtent={ yExtent }
        />
      ) );
    }
  }
  let intervalLimitWarning;
  switch ( historyInterval ) {
    case "hour":
      intervalLimitWarning = "Only showing 1 week's worth of hours";
      break;
    case "day":
      intervalLimitWarning = "Only showing 1 year's worth of days";
      break;
    case "week":
      intervalLimitWarning = "Only showing 10 years worth of weeks";
      break;
    case "month":
      intervalLimitWarning = "Only showing 100 years worth of months";
      break;
    default:
      intervalLimitWarning = "Only showing 100 years worth of years";
  }
  return (
    <div className="HistoryComparison">
      <div className="form-inline">
        <div className="form-group">
          <div className="btn-group" role="group" aria-label="History Layout Controls">
            <button
              className={ `btn btn-${!historyLayout || historyLayout === "combined" ? "primary" : "default"}` }
              onClick={ ( ) => setHistoryLayout( "combined" ) }
            >
              Combined
            </button>
            <button
              className={ `btn btn-${historyLayout === "vertical" ? "primary" : "default"}` }
              onClick={ ( ) => setHistoryLayout( "vertical" ) }
            >
              Vertical
            </button>
            <button
              className={ `btn btn-${historyLayout === "horizontal" ? "primary" : "default"}` }
              onClick={ ( ) => setHistoryLayout( "horizontal" ) }
            >
              Horizontal
            </button>
          </div>
        </div>
        <div className="form-group">
          <label>Interval</label>
          <select
            className="form-control"
            onChange={ e => setHistoryInterval( e.target.value ) }
            defaultValue={ historyInterval }
          >
            { ["hour", "day", "week", "month", "year"].map( interval => (
              <option
                key={ `interval-select-${interval}` }
                value={ interval }
              >
                { interval }
              </option>
            ) ) }
          </select>
        </div>
        <div className="alert alert-info pull-right alert-sm">
          { intervalLimitWarning }
        </div>
      </div>
      <div className={ `charts charts-${historyLayout}` }>
        { charts }
      </div>
    </div>
  );
};

HistoryComparison.propTypes = {
  historyLayout: PropTypes.string,
  historyInterval: PropTypes.string,
  setHistoryLayout: PropTypes.func,
  histories: PropTypes.array,
  queries: PropTypes.array,
  setHistoryInterval: PropTypes.func
};

HistoryComparison.defaultProps = {
  historyLayout: "combined",
  historyInterval: "week",
  queries: [],
  histories: []
};

export default HistoryComparison;
