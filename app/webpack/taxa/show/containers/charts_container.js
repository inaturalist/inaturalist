import { connect } from "react-redux";
import _ from "lodash";
import Charts from "../components/charts";
import {
  fetchMonthFrequency,
  fetchMonthOfYearFrequency,
  openObservationsSearch
} from "../ducks/observations";
import {
  setNoAnnotationHiddenPreference,
  setScaledPreference
} from "../actions/taxon";
import { fetchTerms } from "../../shared/ducks/taxon";

const TERMS_TO_CHART = ["Life Stage", "Plant Phenology", "Sex"];

function mapStateToProps( state ) {
  // process columns for seasonality
  const monthOfYearFrequencyVerifiable = state.observations.monthOfYearFrequency.verifiable || {};
  const seasonalityLoading = _.isEmpty( state.observations.monthOfYearFrequency )
    || !Object.keys( state.observations.monthOfYearFrequency ).includes( "verifiable" )
    || !Object.keys( state.observations.monthOfYearFrequency ).includes( "research" );
  const seasonalityKeys = _.keys(
    monthOfYearFrequencyVerifiable
  )
    .map( monthNum => Number( monthNum ) )
    .sort( ( monthNumA, monthNumB ) => monthNumA - monthNumB );
  const seasonalityColumns = [];
  const seriesNames = [
    "verifiable",
    "research"
  ];
  const monthOfYearFrequencies = { ...state.observations.monthOfYearFrequency };
  const chartedFieldValues = { };
  _.each( state.taxon.fieldValues, ( values, termID ) => {
    if ( !_.includes( TERMS_TO_CHART, values[0].controlled_attribute.label ) ) {
      return;
    }
    chartedFieldValues[termID] = values;
    _.each( values, v => {
      const seriesName = `${v.controlled_attribute.label}=${v.controlled_value.label}`;
      seriesNames.push( seriesName );
      monthOfYearFrequencies[seriesName] = v.month_of_year;
    } );
  } );
  const scaledSeasonality = state.config.prefersScaledFrequencies
    && monthOfYearFrequencies.background;
  for ( let i = 0; i < seriesNames.length; i += 1 ) {
    const series = seriesNames[i];
    const frequency = monthOfYearFrequencies[series];
    if ( frequency ) {
      seasonalityColumns.push(
        [series, ...seasonalityKeys.map( key => {
          let freq = frequency[key.toString( )] || 0;
          if ( scaledSeasonality ) {
            freq /= ( monthOfYearFrequencies.background[key.toString( )] || 1 );
          }
          return freq;
        } )]
      );
    }
  }

  // process columns for history
  const monthFrequencyVerifiable = state.observations.monthFrequency.verifiable || {};
  const monthFrequencyResearch = state.observations.monthFrequency.research || {};
  const historyLoading = _.isEmpty( state.observations.monthFrequency )
    || !Object.keys( state.observations.monthFrequency ).includes( "verifiable" )
    || !Object.keys( state.observations.monthFrequency ).includes( "research" );
  const historyKeys = _.keys( monthFrequencyVerifiable ).sort( );
  const historyColumns = [];
  const scaledHistory = state.config.prefersScaledFrequencies
    && state.observations.monthFrequency.background;
  if ( !_.isEmpty( _.keys( state.observations.monthFrequency ) ) ) {
    historyColumns.push( ["x", ...historyKeys] );
    historyColumns.push( ["verifiable", ...historyKeys.map( d => {
      let freq = monthFrequencyVerifiable[d] || 0;
      if ( scaledHistory ) {
        freq /= ( state.observations.monthFrequency.background[d] || 1 );
      }
      return freq;
    } )] );
    historyColumns.push( ["research", ...historyKeys.map( d => {
      let freq = monthFrequencyResearch[d] || 0;
      if ( scaledHistory ) {
        freq /= ( state.observations.monthFrequency.background[d] || 1 );
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
    noAnnotationHidden: state.config.prefersNoAnnotationHidden,
    scaled: state.config.prefersScaledFrequencies,
    config: state.config,
    historyLoading,
    seasonalityLoading
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    fetchMonthOfYearFrequency: ( ) => dispatch( fetchMonthOfYearFrequency( ) ),
    fetchMonthFrequency: ( ) => dispatch( fetchMonthFrequency( ) ),
    openObservationsSearch: params => dispatch( openObservationsSearch( params ) ),
    setNoAnnotationHiddenPreference: pref => dispatch( setNoAnnotationHiddenPreference( pref ) ),
    setScaledPreference: pref => dispatch( setScaledPreference( pref ) ),
    loadFieldValueChartData: ( ) => dispatch( fetchTerms( { histograms: true } ) )
  };
}

const ChartsContainer = connect(
  mapStateToProps,
  mapDispatchToProps,
  null,
  { pure: false }
)( Charts );

export default ChartsContainer;
