import { connect } from "react-redux";
import _ from "lodash";
import Charts from "../components/charts";
import {
  fetchMonthFrequency,
  fetchMonthOfYearFrequency,
  openObservationsSearch
} from "../ducks/observations";
import { setScaledPreference } from "../actions/taxon";

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
  const scaledSeasonality = state.config.prefersScaledFrequencies &&
    state.observations.monthOfYearFrequency.background;
  for ( let i = 0; i < order.length; i++ ) {
    const series = order[i];
    const frequency = state.observations.monthOfYearFrequency[series];
    if ( frequency ) {
      seasonalityColumns.push(
        [series, ...seasonalityKeys.map( key => {
          let freq = frequency[key.toString( )] || 0;
          if ( scaledSeasonality ) {
            freq = freq / ( state.observations.monthOfYearFrequency.background[key.toString( )] || 1 );
          }
          return freq;
        } )]
      );
    }
  }

  // process columns for history
  const monthFrequencyVerifiable = state.observations.monthFrequency.verifiable || {};
  const monthFrequencyResearch = state.observations.monthFrequency.research || {};
  const historyKeys = _.keys( monthFrequencyVerifiable ).sort( );
  const historyColumns = [];
  const scaledHistory = state.config.prefersScaledFrequencies &&
    state.observations.monthFrequency.background;
  if ( !_.isEmpty( _.keys( state.observations.monthFrequency ) ) ) {
    historyColumns.push( ["x", ...historyKeys] );
    historyColumns.push( ["verifiable", ...historyKeys.map( d => {
      let freq = monthFrequencyVerifiable[d] || 0;
      if ( scaledHistory ) {
        freq = freq / ( state.observations.monthFrequency.background[d] || 1 );
      }
      return freq;
    } )] );
    historyColumns.push( ["research", ...historyKeys.map( d => {
      let freq = monthFrequencyResearch[d] || 0;
      if ( scaledHistory ) {
        freq = freq / ( state.observations.monthFrequency.background[d] || 1 );
      }
      return freq;
    } )] );
  }
  return {
    taxon: state.taxon.taxon,
    seasonalityKeys,
    seasonalityColumns,
    historyColumns,
    historyKeys,
    chartedFieldValues,
    scaled: state.config.prefersScaledFrequencies,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    fetchMonthOfYearFrequency: ( ) => dispatch( fetchMonthOfYearFrequency( ) ),
    fetchMonthFrequency: ( ) => dispatch( fetchMonthFrequency( ) ),
    openObservationsSearch: params => dispatch( openObservationsSearch( params ) ),
    setScaledPreference: pref => dispatch( setScaledPreference( pref ) )
  };
}

const ChartsContainer = connect(
  mapStateToProps,
  mapDispatchToProps,
  null,
  { pure: false }
)( Charts );

export default ChartsContainer;
