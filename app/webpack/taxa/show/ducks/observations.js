import inatjs from "inaturalistjs";
import { defaultObservationParams } from "../../shared/util";

const SET_MONTH_FREQUENCY = "taxa-show/observations/SET_MONTH_FREQUENCY";
const SET_MONTH_OF_YEAR_FREQUENCY = "taxa-show/observations/SET_MONTH_OF_YEAR_FREQUENCY";
const SET_RECENT_OBSERVATIONS = "taxa-show/observations/SET_RECENT_OBSERVATIONS";
const SET_OBSERVATIONS_COUNT = "taxa-show/observations/SET_OBSERVATIONS_COUNT";
const SET_FIRST_OBSERVATION = "taxa-show/observations/SET_FIRST_OBSERVATION";

if ( window.location.protocol.match( /https/ ) ) {
  inatjs.setConfig( {
    apiHostSSL: true,
    writeHostSSL: true
  } );
}

export default function reducer(
  state = { monthOfYearFrequency: {}, monthFrequency: {} },
  action
) {
  const newState = Object.assign( {}, state );
  switch ( action.type ) {
    case SET_MONTH_FREQUENCY:
      newState.monthFrequency = Object.assign( newState.monthFrequency, {
        [action.key]: action.frequency
      } );
      break;
    case SET_MONTH_OF_YEAR_FREQUENCY:
      newState.monthOfYearFrequency = Object.assign( newState.monthOfYearFrequency, {
        [action.key]: action.frequency
      } );
      break;
    case SET_RECENT_OBSERVATIONS:
      newState.recent = action.observations;
      break;
    case SET_OBSERVATIONS_COUNT:
      newState.total = action.count;
      break;
    case SET_FIRST_OBSERVATION:
      newState.first = action.observation;
      break;
    default:
      // leave it alone
  }
  return newState;
}

export function setMonthFrequecy( key, frequency ) {
  return {
    type: SET_MONTH_FREQUENCY,
    key,
    frequency
  };
}

export function setMonthOfYearFrequecy( key, frequency ) {
  return {
    type: SET_MONTH_OF_YEAR_FREQUENCY,
    key,
    frequency
  };
}

export function fetchMonthFrequencyVerifiable( ) {
  return ( dispatch, getState ) => {
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      date_field: "observed",
      interval: "month"
    } );
    return inatjs.observations.histogram( params ).then( response => {
      dispatch( setMonthFrequecy( "verifiable", response.results.month ) );
      return new Promise( ( resolve ) => resolve( response.results.month ) );
    } );
  };
}

export function fetchMonthFrequencyResearchGrade( ) {
  return ( dispatch, getState ) => {
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      date_field: "observed",
      interval: "month",
      quality_grade: "research"
    } );
    return inatjs.observations.histogram( params ).then( response => {
      dispatch( setMonthFrequecy( "research", response.results.month ) );
      return new Promise( ( resolve ) => resolve( response.results.month ) );
    } );
  };
}

export function fetchMonthFrequency( ) {
  return ( dispatch ) => Promise.all( [
    dispatch( fetchMonthFrequencyVerifiable( ) ),
    dispatch( fetchMonthFrequencyResearchGrade( ) )
  ] );
}

export function fetchMonthOfYearFrequencyVerifiable( ) {
  return ( dispatch, getState ) => {
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      date_field: "observed",
      interval: "month_of_year"
    } );
    return inatjs.observations.histogram( params ).then( response => {
      dispatch( setMonthOfYearFrequecy( "verifiable", response.results.month_of_year ) );
      return new Promise( ( resolve ) => resolve( response.results.month_of_year ) );
    } );
  };
}

export function fetchMonthOfYearFrequencyResearchGrade( ) {
  return ( dispatch, getState ) => {
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      date_field: "observed",
      interval: "month_of_year",
      quality_grade: "research"
    } );
    return inatjs.observations.histogram( params ).then( response => {
      dispatch( setMonthOfYearFrequecy( "research", response.results.month_of_year ) );
      return new Promise( ( resolve ) => resolve( response.results.month_of_year ) );
    } );
  };
}

export function fetchMonthOfYearFrequency( ) {
  return ( dispatch ) => Promise.all( [
    dispatch( fetchMonthOfYearFrequencyVerifiable( ) ),
    dispatch( fetchMonthOfYearFrequencyResearchGrade( ) )
  ] );
}

export function setRecentObservations( observations ) {
  return {
    type: SET_RECENT_OBSERVATIONS,
    observations
  };
}

export function setObservationsCount( count ) {
  return {
    type: SET_OBSERVATIONS_COUNT,
    count
  };
}

export function fetchRecentObservations( ) {
  return ( dispatch, getState ) =>
    inatjs.observations.search(
      defaultObservationParams( getState( ) )
    ).then( response => {
      dispatch( setRecentObservations( response.results ) );
      dispatch( setObservationsCount( response.total_results ) );
    } );
}

export function setFirstObservation( observation ) {
  return {
    type: SET_FIRST_OBSERVATION,
    observation
  };
}

export function fetchFirstObservation( ) {
  return ( dispatch, getState ) => {
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      order: "asc",
      per_page: 1
    } );
    return ( inatjs.observations.search( params ).then( response => {
      dispatch( setFirstObservation( response.results[0] ) );
    } ) );
  };
}
