import inatjs from "inaturalistjs";
import _ from "lodash";

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

// This is a utility that doesn't modify the state, but could be useful elsewhere
export function termsForTaxon( terms, taxon = null ) {
  const ancestorIds = taxon && taxon.ancestor_ids ? taxon.ancestor_ids : [];
  return _.filter( terms, term => {
    // reject if it has values and those values and none are availalble
    if ( term.values && term.values.length > 0 &&
         termsForTaxon( term.values, taxon ).length === 0 ) {
      return false;
    }
    // value applies to all taxa without exceptions, keep it
    if (
      ( term.taxon_ids || [] ).length === 0 &&
      ( term.excepted_taxon_ids || [] ).length === 0
    ) {
      return true;
    }
    // remove things with exceptions that include this taxon
    if (
      _.intersection( term.excepted_taxon_ids || [], ancestorIds ).length > 0
    ) {
      return false;
    }
    // no exceptions but applies to all taxa keep it
    if ( ( term.taxon_ids || [] ).length === 0 ) {
      return true;
    }
    return _.intersection( term.taxon_ids || [], ancestorIds ).length > 0;
  } );
}

export function setControlledTermsForTaxon( taxon, terms = [] ) {
  return ( dispatch, getState ) => {
    const allTerms = terms && terms.length > 0 ? terms : getState( ).controlledTerms.allTerms;
    dispatch( setControlledTerms( termsForTaxon( allTerms, taxon ) ) );
  };
}
