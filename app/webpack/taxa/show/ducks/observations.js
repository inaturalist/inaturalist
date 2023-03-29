import _ from "lodash";
import inatjs from "inaturalistjs";
import { stringify } from "querystring";
import { defaultObservationParams } from "../../shared/util";
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
      return new Promise( resolve => resolve( response.results.month ) );
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
      return new Promise( resolve => resolve( response.results.month ) );
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
      return new Promise( resolve => resolve( response.results.month ) );
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
      return new Promise( resolve => resolve( response.results.month_of_year ) );
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
      return new Promise( resolve => resolve( response.results.month_of_year ) );
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
      return new Promise( resolve => resolve( response.results.month_of_year ) );
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
  return ( dispatch, getState ) => {
    const state = getState( );
    const { testingApiV2 } = state.config;
    const params = {
      ...defaultObservationParams( getState( ) ),
      return_bounds: true
    };
    if ( testingApiV2 ) {
      params.fields = {
        id: true,
        observed_on: true,
        photos: {
          id: true,
          uuid: true,
          url: true,
          license_code: true
        },
        taxon: {
          id: true,
          uuid: true,
          name: true,
          iconic_taxon_name: true,
          is_active: true,
          preferred_common_name: true,
          rank: true,
          rank_level: true
        },
        user: {
          id: true,
          login: true,
          name: true
        }
      };
    }
    return inatjs.observations.search( params ).then( response => {
      dispatch( setRecentObservations( response.results ) );
      dispatch( setObservationsCount( response.total_results ) );
      dispatch( setConfig( { mapBounds: response.total_bounds } ) );
    } );
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
    const state = getState( );
    const { testingApiV2 } = state.config;
    const params = {
      ...defaultObservationParams( getState( ) ),
      order_by: "observed_on",
      order: "desc",
      per_page: 1,
      skip_total_hits: true
    };
    if ( testingApiV2 ) {
      params.fields = {
        id: true,
        observed_on: true,
        photos: {
          id: true,
          uuid: true,
          url: true,
          license_code: true
        }
      };
    }
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
