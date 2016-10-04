import fetch from "isomorphic-fetch";
import iNaturalistJS from "inaturalistjs";

const SET_TAXON = "taxa-show/taxon/SET_TAXON";
const SET_DESCRIPTION = "taxa-show/taxon/SET_DESCRIPTION";
const SET_LINKS = "taxa-show/taxon/SET_LINKS";
const SET_COUNT = "taxa-show/taxon/SET_COUNT";

export default function reducer( state = { counts: {} }, action ) {
  const newState = Object.assign( { }, state );
  switch ( action.type ) {
    case SET_TAXON:
      newState.taxon = action.taxon;
      break;
    case SET_DESCRIPTION:
      newState.description = {
        source: action.source,
        url: action.url,
        body: action.body
      };
      break;
    case SET_LINKS:
      newState.links = action.links;
      break;
    case SET_COUNT:
      newState.counts = state.counts || {};
      newState.counts[action.count] = action.value;
      break;
    default:
      // nothing to see here
  }
  return newState;
}

export function setTaxon( taxon ) {
  return {
    type: SET_TAXON,
    taxon
  };
}

export function setDescription( source, url, body ) {
  return {
    type: SET_DESCRIPTION,
    source,
    url,
    body
  };
}

export function setLinks( links ) {
  return {
    type: SET_LINKS,
    links
  };
}

export function setCount( count, value ) {
  return {
    type: SET_COUNT,
    count,
    value
  };
}

export function fetchTaxon( taxon ) {
  return ( dispatch ) =>
    iNaturalistJS.taxa.fetch( taxon.id ).then( response => {
      dispatch( setTaxon( response.results[0] ) );
    } );
}

export function fetchDescription( ) {
  return ( dispatch, getState ) => {
    const taxon = getState( ).taxon.taxon;
    fetch( `/taxa/${taxon.id}/description` ).then(
      response => {
        const source = response.headers.get( "X-Describer-Name" );
        const url = response.headers.get( "X-Describer-URL" );
        response.text( ).then(
          body => dispatch( setDescription( source, url, body )
        ) );
      },
      error => {
        console.log( "[DEBUG] error: ", error );
      }
    );
  };
}

export function fetchLinks( ) {
  return ( dispatch, getState ) => {
    const taxon = getState( ).taxon.taxon;
    fetch( `/taxa/${taxon.id}/links.json` ).then(
      response => {
        response.json( ).then( json => dispatch( setLinks( json ) ) );
      },
      error => {
        console.log( "[DEBUG] error: ", error );
      }
    );
  };
}
