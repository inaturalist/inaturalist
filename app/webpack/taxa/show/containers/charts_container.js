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
  const order = [
    "Flowering Phenology=bare",
    "Flowering Phenology=budding",
    "Flowering Phenology=flower",
    "Flowering Phenology=fruit",
    "Insect life stage=egg",
    "Insect life stage=larva",
    "Insect life stage=teneral",
    "Insect life stage=nymph",
    "Insect life stage=pupa",
    "Insect life stage=adult",
    "verifiable",
    "research"
  ];
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
