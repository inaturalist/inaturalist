import _ from "lodash";
import inatjs from "inaturalistjs";
import { defaultObservationParams } from "../../shared/util";
import { stringify } from "querystring";
import { setConfig } from "../../../shared/ducks/config";

const SET_MONTH_FREQUENCY = "taxa-show/observations/SET_MONTH_FREQUENCY";
const SET_MONTH_OF_YEAR_FREQUENCY = "taxa-show/observations/SET_MONTH_OF_YEAR_FREQUENCY";
const SET_RECENT_OBSERVATIONS = "taxa-show/observations/SET_RECENT_OBSERVATIONS";
const SET_OBSERVATIONS_COUNT = "taxa-show/observations/SET_OBSERVATIONS_COUNT";
const SET_FIRST_OBSERVATION = "taxa-show/observations/SET_FIRST_OBSERVATION";
const SET_LAST_OBSERVATION = "taxa-show/observations/SET_LAST_OBSERVATION";
const RESET_STATE = "taxa-show/observations/RESET_STATE";

const INITIAL_STATE = { monthOfYearFrequency: {}, monthFrequency: {} };

export default function reducer(
  state = INITIAL_STATE,
  action
) {
  let newState = Object.assign( {}, state );
  switch ( action.type ) {
    case RESET_STATE:
      newState = INITIAL_STATE;
      newState.monthOfYearFrequency = {};
      newState.monthFrequency = {};
      break;
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
    case SET_LAST_OBSERVATION:
      newState.last = action.observation;
      break;
    default:
      // leave it alone
  }
  return newState;
}

export function resetObservationsState( ) {
  return { type: RESET_STATE };
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

export function fetchMonthFrequencyBackground( ) {
  return ( dispatch, getState ) => {
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      date_field: "observed",
      interval: "month"
    } );
    delete params.taxon_id;
    return inatjs.observations.histogram( params ).then( response => {
      dispatch( setMonthFrequecy( "background", response.results.month ) );
      return new Promise( ( resolve ) => resolve( response.results.month ) );
    } );
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
  return ( dispatch, getState ) => {
    const promises = [
      dispatch( fetchMonthFrequencyVerifiable( ) ),
      dispatch( fetchMonthFrequencyResearchGrade( ) )
    ];
    if ( getState( ).config.prefersScaledFrequencies ) {
      promises.push( dispatch( fetchMonthFrequencyBackground( ) ) );
    }
    Promise.all( promises );
  };
}

export function fetchMonthOfYearFrequencyBackground( ) {
  return ( dispatch, getState ) => {
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      date_field: "observed",
      interval: "month_of_year"
    } );
    delete params.taxon_id;
    return inatjs.observations.histogram( params ).then( response => {
      dispatch( setMonthOfYearFrequecy( "background", response.results.month_of_year ) );
      return new Promise( ( resolve ) => resolve( response.results.month_of_year ) );
    } );
  };
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
  return ( dispatch, getState ) => {
    const promises = [
      dispatch( fetchMonthOfYearFrequencyVerifiable( ) ),
      dispatch( fetchMonthOfYearFrequencyResearchGrade( ) )
    ];
    if ( getState( ).config.prefersScaledFrequencies ) {
      promises.push( dispatch( fetchMonthOfYearFrequencyBackground( ) ) );
    }
    const fieldValues = getState( ).taxon.fieldValues;
    if ( fieldValues && _.size( fieldValues ) > 0 ) {
      _.each( fieldValues, values => {
        _.each( values, value => {
          dispatch( setMonthOfYearFrequecy(
            `${value.controlled_attribute.label}=${value.controlled_value.label}`,
            value.month_of_year ) );
        } );
      } );
    }
    return Promise.all( promises );
  };
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
      Object.assign( { return_bounds: true }, defaultObservationParams( getState( ) ) )
    ).then( response => {
      dispatch( setRecentObservations( response.results ) );
      dispatch( setObservationsCount( response.total_results ) );
      dispatch( setConfig( { mapBounds: response.total_bounds } ) );
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

export function setLastObservation( observation ) {
  return {
    type: SET_LAST_OBSERVATION,
    observation
  };
}

export function fetchLastObservation( ) {
  return ( dispatch, getState ) => {
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      order_by: "observed_on",
      order: "desc",
      per_page: 1
    } );
    return ( inatjs.observations.search( params ).then( response => {
      dispatch( setLastObservation( response.results[0] ) );
    } ) );
  };
}

export function openObservationsSearch( params ) {
  return ( dispatch, getState ) => {
    const searchParams = Object.assign( { }, defaultObservationParams( getState( ) ), params );
    window.open( `/observations?${stringify( searchParams )}`, "_blank" );
  };
}

