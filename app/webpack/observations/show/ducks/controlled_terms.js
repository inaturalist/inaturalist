import inatjs from "inaturalistjs";

const SET_CONTROLLED_TERMS = "obs-show/controlled_terms/SET_CONTROLLED_TERMS";

export default function reducer( state = [], action ) {
  switch ( action.type ) {
    case SET_CONTROLLED_TERMS:
      return action.terms;
    default:
      // nothing to see here
  }
  return state;
}

export function setControlledTerms( terms ) {
  return {
    type: SET_CONTROLLED_TERMS,
    terms
  };
}

export function fetchControlledTerms( options = {} ) {
  return ( dispatch, getState ) => {
    const observation = options.observation || getState( ).observation;
    if ( !observation || !observation.taxon ) {
      return null;
    }
    const params = { taxon_id: observation.taxon.ancestor_ids.join( "," ), ttl: -1 };
    return inatjs.controlled_terms.for_taxon( params ).then( response => {
      dispatch( setControlledTerms( response.results ) );
    } ).catch( e => { } );
  };
}
