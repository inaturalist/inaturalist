import React from "react";
import PropTypes from "prop-types";
import {
  timeFormat,
  extent,
  isoParse
} from "d3";
import _ from "lodash";
import DateHistogram from "../../../shared/components/date_histogram";
import Histogram from "../../../shared/components/histogram";

const HistoryComparison = ( {
  historyDateField,
  historyLayout,
  historyInterval,
  setHistoryDateField,
  setHistoryLayout,
  histories,
  queries,
  setHistoryInterval
} ) => {
  let charts;
  if ( histories.length === queries.length ) {
    let labeler;
    if ( historyInterval === "hour" ) {
      const hourFormat = timeFormat( "%H:%M" );
      labeler = d => `<strong>${hourFormat( d.date )}</strong>: ${d.value}`;
    }
    let xAttr;
    let HistogramComponent;
    let xParser;
    switch ( historyInterval ) {
      case "week_of_year":
        xAttr = "week";
        HistogramComponent = Histogram;
        xParser = x => parseInt( x, 0 );
        break;
      case "month_of_year":
        xAttr = "month";
        HistogramComponent = Histogram;
        xParser = x => parseInt( x, 0 );
        break;
      default:
        xAttr = "date";
        HistogramComponent = DateHistogram;
    }
    if ( historyLayout === "combined" ) {
      const series = {};
      _.forEach( queries, ( query, i ) => {
        series[`query-${query.name}`] = {
          title: query.name,
          data: _.map(
            histories[i],
            ( value, key ) => ( { [xAttr]: key, value } )
          ),
          color: query.color,
          label: labeler
        };
      } );
      charts = (
        <HistogramComponent
          key={`Histogram-${queries.map( q => q.name ).join( "_" )}-${historyLayout}-${historyInterval}`}
          series={series}
          xAttr={xAttr}
          xParser={xParser}
        />
      );
    } else {
      let allXValues = _.flatten(
        _.map( histories, history => Object.keys( history ) )
      );
      if ( xAttr === "date" ) {
        allXValues = allXValues.map( isoParse );
      } else {
        allXValues = allXValues.map( x => parseInt( x, 0 ) );
      }
      const allYValues = _.flatten( _.map( histories, history => _.values( history ) ) );
      const xExtent = extent( allXValues );
      const yExtent = extent( allYValues );
      charts = queries.map( ( query, i ) => (
        <HistogramComponent
          key={`Histogram-${query.params}-${i}-${historyLayout}-${historyInterval}`}
          xAttr={xAttr}
          series={{
            [`query-${query.name}`]: {
              title: query.name,
              data: _.map( histories[i], ( value, key ) => ( { [xAttr]: key, value } ) ),
              color: query.color,
              label: labeler
            }
          }}
          xExtent={xExtent}
          yExtent={yExtent}
          xParser={xParser}
        />
      ) );
    }
  }
  let intervalLimitWarning;
  switch ( historyInterval ) {
    case "hour":
      intervalLimitWarning = I18n.t( "views.observations.compare.interval_limit_warning_hour" );
      break;
    case "day":
      intervalLimitWarning = I18n.t( "views.observations.compare.interval_limit_warning_day" );
      break;
    case "week":
      intervalLimitWarning = I18n.t( "views.observations.compare.interval_limit_warning_week" );
      break;
    case "month":
      intervalLimitWarning = I18n.t( "views.observations.compare.interval_limit_warning_month" );
      break;
    case "year":
      intervalLimitWarning = I18n.t( "views.observations.compare.interval_limit_warning_year" );
      break;
    default:
      // No need to show a warning for the seasonality intervals
      intervalLimitWarning = null;
  }
  return (
    <div className="HistoryComparison">
      <div className="form-inline">
        <div className="form-group">
          <div className="btn-group" role="group" aria-label="History Layout Controls">
            <button
              type="button"
              className={`btn btn-${!historyLayout || historyLayout === "combined" ? "primary" : "default"}`}
              onClick={( ) => setHistoryLayout( "combined" )}
            >
              { I18n.t( "views.observations.compare.combined" ) }
            </button>
            <button
              type="button"
              className={`btn btn-${historyLayout === "vertical" ? "primary" : "default"}`}
              onClick={( ) => setHistoryLayout( "vertical" )}
            >
              { I18n.t( "views.observations.compare.vertical" ) }
            </button>
            <button
              type="button"
              className={`btn btn-${historyLayout === "horizontal" ? "primary" : "default"}`}
              onClick={( ) => setHistoryLayout( "horizontal" )}
            >
              { I18n.t( "views.observations.compare.horizontal" ) }
            </button>
          </div>
        </div>
        <div className="form-group">
          <label>{ I18n.t( "views.observations.compare.interval" ) }</label>
          <select
            className="form-control"
            onChange={e => setHistoryInterval( e.target.value )}
            defaultValue={historyInterval}
          >
            { ["hour", "day", "week", "month", "year", "week_of_year", "month_of_year"].map( interval => (
              <option
                key={`interval-select-${interval}`}
                value={interval}
              >
                { I18n.t( interval, { defaultValue: interval } ) }
              </option>
            ) ) }
          </select>
        </div>
        <div className="form-group">
          <label>{ I18n.t( "views.observations.compare.date_field" ) }</label>
          <select
            className="form-control"
            onChange={e => setHistoryDateField( e.target.value )}
            defaultValue={historyDateField}
          >
            { ["observed", "created"].map( dateField => (
              <option
                key={`date-field-select-${dateField}`}
                value={dateField}
              >
                { I18n.t( dateField, { defaultValue: dateField } ) }
              </option>
            ) ) }
          </select>
        </div>
        { intervalLimitWarning && (
          <div className="alert alert-info pull-right alert-sm">
            { intervalLimitWarning }
          </div>
        ) }
      </div>
      <div className={`charts charts-${historyLayout}`}>
        { charts }
      </div>
    </div>
  );
};

HistoryComparison.propTypes = {
  histories: PropTypes.array,
  historyDateField: PropTypes.string,
  historyInterval: PropTypes.string,
  historyLayout: PropTypes.string,
  queries: PropTypes.array,
  setHistoryDateField: PropTypes.func,
  setHistoryInterval: PropTypes.func,
  setHistoryLayout: PropTypes.func
};

HistoryComparison.defaultProps = {
  historyDateField: "observed",
  historyLayout: "combined",
  historyInterval: "week",
  queries: [],
  histories: []
};

export default HistoryComparison;
