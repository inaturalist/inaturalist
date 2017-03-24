import { connect } from "react-redux";
import _ from "lodash";
import Charts from "../components/charts";
import {
  fetchMonthFrequency,
  fetchMonthOfYearFrequency,
  openObservationsSearch
} from "../ducks/observations";

const TERMS_TO_CHART = ["Life Stage", "Plant Phenology"];

function mapStateToProps( state ) {
  // process columns for seasonality
  const monthOfYearFrequencyVerifiable = state.observations.monthOfYearFrequency.verifiable || {};
  const seasonalityKeys = _.keys(
    monthOfYearFrequencyVerifiable
  ).map( k => parseInt( k, 0 ) ).sort( ( a, b ) => a - b );
  const seasonalityColumns = [];
  const order = [
    "verifiable",
    "research"
  ];
  const chartedFieldValues = { };
  _.each( state.taxon.fieldValues, ( values, termID ) => {
    if ( !_.includes( TERMS_TO_CHART, values[0].controlled_attribute.label ) ) {
      return;
    }
    chartedFieldValues[termID] = values;
    _.each( values, v => {
      order.push( `${v.controlled_attribute.label}=${v.controlled_value.label}` );
    } );
  } );
  for ( let i = 0; i < order.length; i++ ) {
    const series = order[i];
    const frequency = state.observations.monthOfYearFrequency[series];
    if ( frequency ) {
      seasonalityColumns.push(
        [series, ...seasonalityKeys.map( key => frequency[key.toString( )] || 0 )]
      );
    }
  }

  // process columns for history
  const monthFrequencyVerifiable = state.observations.monthFrequency.verifiable || {};
  const monthFrequencyResearch = state.observations.monthFrequency.research || {};
  const historyKeys = _.keys( monthFrequencyVerifiable ).sort( );
  const historyColumns = [];
  if ( !_.isEmpty( _.keys( state.observations.monthFrequency ) ) ) {
    historyColumns.push( ["x", ...historyKeys] );
    historyColumns.push( ["verifiable", ...historyKeys.map( d =>
      monthFrequencyVerifiable[d] || 0 )] );
    historyColumns.push( ["research", ...historyKeys.map( d =>
      monthFrequencyResearch[d] || 0 )] );
  }
  return {
    seasonalityKeys,
    seasonalityColumns,
    historyColumns,
    historyKeys,
    chartedFieldValues
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
