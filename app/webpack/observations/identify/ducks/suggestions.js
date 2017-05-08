import inatjs from "inaturalistjs";

const RESET = "observations-identify/suggestions/RESET";
const SET_QUERY = "observations-identify/suggestions/SET_QUERY";
const SET_SUGGESTIONS = "observations-identify/suggestions/SET_SUGGESTIONS";
const SET_DETAIL_TAXON = "observations-identify/suggestions/SET_DETAIL_TAXON";

export default function reducer(
  state = {},
  action
) {
  let newState = Object.assign( {}, state );
  switch ( action.type ) {
    case RESET:
      newState = {};
      break;
    case SET_QUERY:
      newState.query = action.query;
      break;
    case SET_SUGGESTIONS:
      newState.response = action.suggestions;
      newState.detailTaxon = null;
      break;
    case SET_DETAIL_TAXON:
      newState.detailTaxon = action.taxon;
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

export function setDetailTaxon( taxon ) {
  return { type: SET_DETAIL_TAXON, taxon };
}

export function fetchSuggestions( query ) {
  return function ( dispatch, getState ) {
    let newQuery = {};
    if ( query ) {
      newQuery = query;
    } else {
      const observation = getState( ).currentObservation.observation;
      newQuery.observation_id = observation.id;
    }
    dispatch( setQuery( newQuery ) );
    return inatjs.taxa.suggest( newQuery ).then( suggestions => {
      dispatch( setSuggestions( suggestions ) );
    } );
  };
}
