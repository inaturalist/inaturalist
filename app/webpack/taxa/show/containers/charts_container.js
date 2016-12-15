import { connect } from "react-redux";
import _ from "lodash";
import Charts from "../components/charts";
import {
  fetchMonthFrequency,
  fetchMonthOfYearFrequency,
  openObservationsSearch
} from "../ducks/observations";

function mapStateToProps( state ) {
  // process columns for seasonality
  const monthOfYearFrequencyVerifiable = state.observations.monthOfYearFrequency.verifiable || {};
  const seasonalityKeys = _.keys(
    monthOfYearFrequencyVerifiable
  ).map( k => parseInt( k, 0 ) ).sort( ( a, b ) => a - b );
  const seasonalityColumns = [];
  _.forEach( state.observations.monthOfYearFrequency, ( frequency, series ) => {
    seasonalityColumns.push(
      [series, ...seasonalityKeys.map( i => frequency[i.toString( )] || 0 )]
    );
  } );

  // process columns for history
  const monthFrequencyVerifiable = state.observations.monthFrequency.verifiable || {};
  const historyKeys = _.keys( monthFrequencyVerifiable ).sort( );
  const historyColumns = [];
  if ( !_.isEmpty( _.keys( state.observations.monthFrequency ) ) ) {
    historyColumns.push( ["x", ...historyKeys] );
  }
  _.forEach( state.observations.monthFrequency, ( frequency, series ) => {
    historyColumns.push( [series, ...historyKeys.map( d => frequency[d] || 0 )] );
  } );
  return {
    seasonalityKeys,
    seasonalityColumns,
    historyColumns,
    historyKeys
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    fetchMonthOfYearFrequency: ( ) => dispatch( fetchMonthOfYearFrequency( ) ),
    fetchMonthFrequency: ( ) => dispatch( fetchMonthFrequency( ) ),
    openObservationsSearch: params => dispatch( openObservationsSearch( params ) )
  };
}

const ChartsContainer = connect(
  mapStateToProps,
  mapDispatchToProps,
  null,
  { pure: false }
)( Charts );

export default ChartsContainer;
