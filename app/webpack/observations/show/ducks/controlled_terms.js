import inatjs from "inaturalistjs";

const SET_CONTROLLED_TERMS = "obs-show/controlled_terms/SET_CONTROLLED_TERMS";
const SET_ALL_CONTROLLED_TERMS = "obs-show/controlled_terms/SET_ALL_CONTROLLED_TERMS";

export default function reducer( state = { terms: [], allTerms: [] }, action ) {
  const newState = Object.assign( {}, state );
  switch ( action.type ) {
    case SET_CONTROLLED_TERMS:
      newState.terms = action.terms;
      break;
    case SET_ALL_CONTROLLED_TERMS:
      newState.allTerms = action.terms;
      break;
    default:
      // nothing to see here
  }
  return newState;
}

export function setControlledTerms( terms ) {
  return {
    type: SET_CONTROLLED_TERMS,
    terms
  };
}

export function setAllControlledTerms( terms ) {
  return {
    type: SET_ALL_CONTROLLED_TERMS,
    terms
  };
}


export function fetchControlledTerms( options = {} ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const observation = options.observation || state.observation;
    if ( !observation || !observation.taxon ) {
      if ( state.controlledTerms.allTerms && state.controlledTerms.allTerms.length > 0 ) {
        dispatch( setControlledTerms( state.controlledTerms.allTerms ) );
      } else {
        inatjs.controlled_terms.search( ).then( response => {
          dispatch( setAllControlledTerms( response.results ) );
          dispatch( setControlledTerms( response.results ) );
        } );
      }
      return null;
    }
    const params = { taxon_id: observation.taxon.ancestor_ids.join( "," ), ttl: -1 };
    return inatjs.controlled_terms.for_taxon( params ).then( response => {
      dispatch( setControlledTerms( response.results ) );
    } ).catch( e => { } );
  };
}

export function fetchAllControlledTerms( ) {
  return dispatch =>
    inatjs.controlled_terms.search( ).then( response => {
      dispatch( setAllControlledTerms( response.results ) );
    } ).catch( e => { } );
}
