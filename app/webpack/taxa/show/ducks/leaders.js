import inatjs from "inaturalistjs";
import {
  fetchRecentObservations,
  fetchLastObservation
} from "./observations";
import { defaultObservationParams } from "../../shared/util";

const SET_LEADER = "taxa-show/leaders/SET_LEADER";
const RESET_STATE = "taxa-show/leaders/RESET_STATE";

const INITIAL_STATE = { topObserver: {}, topIdentifier: {}, firstObserver: {}, topSpecies: {} };

export default function reducer(
  state = INITIAL_STATE,
  action
) {
  let newState = Object.assign( {}, state );
  switch ( action.type ) {
    case RESET_STATE:
      newState = INITIAL_STATE;
      break;
    case SET_LEADER:
      newState[action.key] = action.leader;
      break;
    default:
      // leave it alone
  }
  return newState;
}

export function resetLeadersState( ) {
  return { type: RESET_STATE };
}

export function setLeader( key, leader ) {
  return {
    type: SET_LEADER,
    key,
    leader
  };
}

export function fetchTopObserver( ) {
  return function ( dispatch, getState ) {
    return inatjs.observations.observers( defaultObservationParams( getState( ) ) )
      .then( response => dispatch( setLeader( "topObserver", response.results[0] ) ) );
  };
}

export function fetchTopIdentifier( ) {
  return function ( dispatch, getState ) {
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      own_observation: false
    } );
    return inatjs.identifications.identifiers( params )
      .then( response => dispatch( setLeader( "topIdentifier", response.results[0] ) ) );
  };
}

export function fetchFirstObserver( ) {
  return function ( dispatch, getState ) {
    return inatjs.observations.search( defaultObservationParams( getState( ) ) ).then( response => {
      if ( !response.results[0] ) {
        return;
      }
      dispatch( setLeader( "firstObserver", {
        user: response.results[0].user,
        observeration: response.results[0]
      } ) );
    } );
  };
}

export function fetchTopSpecies( ) {
  return function ( dispatch, getState ) {
    return inatjs.observations.speciesCounts( defaultObservationParams( getState( ) ) )
      .then( response => dispatch( setLeader( "topSpecies", response.results[0] ) ) );
  };
}

export function fetchLeaders( selectedTaxon ) {
  return ( dispatch, getState ) => {
    const taxon = selectedTaxon || getState( ).taxon.taxon;
    const promises = [
      dispatch( fetchTopObserver( ) ),
      dispatch( fetchTopIdentifier( ) ),
      dispatch( fetchRecentObservations( taxon ) ),
      dispatch( fetchLastObservation( taxon ) )
    ];
    if ( taxon.rank_level <= 10 ) {
      promises.push( dispatch( fetchFirstObserver( taxon ) ) );
    } else {
      promises.push( dispatch( fetchTopSpecies( taxon ) ) );
    }
    return Promise.all( promises );
  };
}
