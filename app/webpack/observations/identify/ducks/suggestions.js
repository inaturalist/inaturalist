import inatjs from "inaturalistjs";
import _ from "lodash";

import { SHOW_CURRENT_OBSERVATION } from "../actions/current_observation_actions";

const RESET = "observations-identify/suggestions/RESET";
const SET_QUERY = "observations-identify/suggestions/SET_QUERY";
const SET_SUGGESTIONS = "observations-identify/suggestions/SET_SUGGESTIONS";
const SET_DETAIL_TAXON = "observations-identify/suggestions/SET_DETAIL_TAXON";

export default function reducer(
  state = {
    query: {}
  },
  action
) {
  let newState = Object.assign( {}, state );
  switch ( action.type ) {
    case RESET:
      newState = {};
      break;
    case SET_QUERY:
      newState.query = action.query || {};
      break;
    case SET_SUGGESTIONS:
      newState.response = action.suggestions;
      newState.detailTaxon = null;
      break;
    case SET_DETAIL_TAXON:
      newState.detailTaxon = action.taxon;
      break;
    case SHOW_CURRENT_OBSERVATION:
      newState.query = {};
      break;
    default:
      // leave it alone
  }
  return newState;
}

function setSuggestions( suggestions ) {
  return { type: SET_SUGGESTIONS, suggestions };
}

function setQuery( query ) {
  return { type: SET_QUERY, query };
}

export function updateQuery( query ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const newQuery = Object.assign( { }, s.suggestions.query, query );
    if ( query.place && !query.place_id ) {
      newQuery.place_id = query.place.id;
    }
    if ( query.taxon && !query.taxon_id ) {
      newQuery.taxon_id = query.taxon.id;
    }
    if (
      query.taxon_id &&
      !query.taxon &&
      s.currentObservation.observation &&
      s.currentObservation.observation.taxon &&
      s.currentObservation.observation.taxon.id === query.taxon_id
    ) {
      newQuery.taxon = s.currentObservation.observation.taxon;
    }
    if ( query.taxon_id && !query.taxon ) {
      inatjs.taxa.fetch( query.taxon_id )
        .then( response => {
          if ( response.results[0] ) {
            dispatch( updateQuery( { taxon: response.results[0] } ) );
          }
        } );
    }
    if ( query.place_id && !query.place ) {
      inatjs.places.fetch( query.place_id )
        .then( response => {
          if ( response.results[0] ) {
            dispatch( updateQuery( { place: response.results[0] } ) );
          }
        } );
    }
    dispatch( setQuery( newQuery ) );
  };
}

export function setDetailTaxon( taxon ) {
  return { type: SET_DETAIL_TAXON, taxon };
}

export function fetchSuggestions( query ) {
  return function ( dispatch, getState ) {
    const s = getState( );
    let newQuery = {};
    if ( query && _.keys( query ).length > 0 ) {
      newQuery = query;
    } else if ( s.suggestions.query && _.keys( s.suggestions.query ).length > 0 ) {
      newQuery = s.suggestions.query;
    } else {
      const observation = s.currentObservation.observation;
      if ( observation.taxon ) {
        if ( observation.taxon.rank_level <= 10 ) {
          newQuery.taxon_id = observation.taxon.ancestor_ids[observation.taxon.ancestor_ids.length - 2];
        } else {
          newQuery.taxon_id = observation.taxon.id;
        }
      }
      if ( observation.place_ids && observation.place_ids.length > 0 ) {
        newQuery.place_id = observation.place_ids[observation.place_ids.length - 1];
      }
    }
    dispatch( updateQuery( newQuery ) );
    return inatjs.taxa.suggest( newQuery ).then( suggestions => {
      dispatch( setSuggestions( suggestions ) );
    } );
  };
}
