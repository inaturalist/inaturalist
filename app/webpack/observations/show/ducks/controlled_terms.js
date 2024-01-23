import inatjs from "inaturalistjs";
import _ from "lodash";

const SET_CONTROLLED_TERMS = "obs-show/controlled_terms/SET_CONTROLLED_TERMS";
const SET_ALL_CONTROLLED_TERMS = "obs-show/controlled_terms/SET_ALL_CONTROLLED_TERMS";
const RESET_CONTROLLED_TERMS = "obs-show/controlled_terms/RESET_CONTROLLED_TERMS";

const API_V2_BASE_REQUEST_PARAMS = {
  fields: {
    excepted_taxon_ids: true,
    label: true,
    multivalued: true,
    taxon_ids: true,
    values: {
      blocking: true,
      excepted_taxon_ids: true,
      label: true,
      taxon_ids: true
    }
  }
};

export default function reducer( state = {
  terms: [],
  allTerms: [],
  loaded: false,
  open: false
}, action ) {
  const newState = Object.assign( {}, state );
  switch ( action.type ) {
    case SET_CONTROLLED_TERMS:
      newState.terms = action.terms;
      newState.loaded = true;
      break;
    case SET_ALL_CONTROLLED_TERMS:
      newState.allTerms = action.terms;
      newState.loaded = true;
      break;
    case RESET_CONTROLLED_TERMS:
      newState.terms = [];
      newState.allTerms = [];
      newState.loaded = false;
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

export function resetControlledTerms( ) {
  return {
    type: RESET_CONTROLLED_TERMS
  };
}

export function fetchControlledTerms( options = {} ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( state.controlledTerms && state.controlledTerms.loaded ) {
      return null;
    }
    const { testingApiV2 } = state.config;
    const observation = options.observation || state.observation;
    if ( !observation || !observation.taxon || !observation.taxon.ancestor_ids ) {
      if ( state.controlledTerms.allTerms && state.controlledTerms.allTerms.length > 0 ) {
        dispatch( setControlledTerms( state.controlledTerms.allTerms ) );
      } else {
        inatjs.controlled_terms.search(
          testingApiV2 ? API_V2_BASE_REQUEST_PARAMS : {}
        ).then( response => {
          dispatch( setAllControlledTerms( response.results ) );
          dispatch( setControlledTerms( response.results ) );
        } );
      }
      return null;
    }
    const params = Object.assign(
      {},
      testingApiV2 ? API_V2_BASE_REQUEST_PARAMS : {},
      { taxon_id: observation.taxon.ancestor_ids.join( "," ), ttl: -1 }
    );
    return inatjs.controlled_terms.for_taxon( params ).then( response => {
      dispatch( setControlledTerms( response.results ) );
    } ).catch( ( ) => { } );
  };
}

export function fetchAllControlledTerms( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const { testingApiV2 } = state.config;
    inatjs.controlled_terms.search( testingApiV2 ? API_V2_BASE_REQUEST_PARAMS : {} )
      .then( response => dispatch( setAllControlledTerms( response.results ) ) )
      .catch( ( ) => { } );
  };
}

// This is a utility that doesn't modify the state, but could be useful elsewhere
export function termsForTaxon( terms, taxon = null ) {
  const ancestorIds = taxon && taxon.ancestor_ids ? taxon.ancestor_ids : [];
  const filteredTerms = _.filter( terms, term => {
    // reject if it has values and those values and none are availalble
    if (
      term.values && term.values.length > 0
      && termsForTaxon( term.values, taxon ).length === 0
    ) {
      return false;
    }
    // value applies to all taxa without exceptions, keep it
    if (
      ( term.taxon_ids || [] ).length === 0
      && ( term.excepted_taxon_ids || [] ).length === 0
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
  return _.sortBy( filteredTerms, term => I18n.t( `controlled_term_labels.${_.snakeCase( term.label )}`, {
    defaultValue: term.label
  } ) );
}

export function setControlledTermsForTaxon( taxon, terms = [] ) {
  return ( dispatch, getState ) => {
    const allTerms = terms && terms.length > 0 ? terms : getState( ).controlledTerms.allTerms;
    dispatch( setControlledTerms( termsForTaxon( allTerms, taxon ) ) );
  };
}
