import inatjs from "inaturalistjs";
import {
  fetchRecentObservations,
  fetchFirstObservation
} from "./observations";
import { defaultObservationParams } from "../../shared/util";

const SET_LEADER = "taxa-show/leaders/SET_LEADER";

export default function reducer(
  state = { topObserver: {}, topIdentifier: {}, firstObserver: {}, topSpecies: {} },
  action
) {
  const newState = Object.assign( {}, state );
  switch ( action.type ) {
    case SET_LEADER:
      newState[action.key] = action.leader;
      break;
    default:
      // leave it alone
  }
  return newState;
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
    return inatjs.observations.identifiers( defaultObservationParams( getState( ) ) )
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
    dispatch( fetchTopObserver( ) );
    dispatch( fetchTopIdentifier( ) );
    if ( taxon.rank_level <= 10 ) {
      dispatch( fetchFirstObserver( taxon ) );
    } else {
      dispatch( fetchTopSpecies( taxon ) );
    }
    dispatch( fetchRecentObservations( taxon ) );
    dispatch( fetchFirstObservation( taxon ) );
  };
}
