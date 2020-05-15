import _ from "lodash";
import inatjs from "inaturalistjs";
import PromisePool from "es6-promise-pool";
import {
  searchWrapper
} from "../../../shared/ducks/inat_api_duck";

const SET_ATTRIBUTES = "lifelists-show/SET_ATTRIBUTES";
const UPDATE_COMMON_NAMES = "lifelists-show/UPDATE_COMMON_NAMES";

const observationsSearch = searchWrapper( "observations" );
const speciesSearch = searchWrapper( "species" );

export default function reducer( state = {
  loading: true,
  user: null,
  openTaxa: [],
  navView: "tree",
  detailsView: "species",
  detailsTaxon: null,
  detailsTaxonObservations: null
}, action ) {
  switch ( action.type ) {
    case SET_ATTRIBUTES:
      return Object.assign( { }, state, action.attributes );
    case UPDATE_COMMON_NAMES:
      const modifiedTaxa = _.each( state.taxa, t => {
        if ( t.id in action.commonNames ) {
          t.common_name_loaded = true;
          t.preferred_common_name = action.commonNames[t.id];
        }
        return t;
      } );
      return Object.assign( { }, state, { taxa: modifiedTaxa } );
    default:
  }
  return state;
}

export function setAttributes( attributes ) {
  return {
    type: SET_ATTRIBUTES,
    attributes
  };
}

export function updateCommonNames( commonNames ) {
  return {
    type: UPDATE_COMMON_NAMES,
    commonNames
  };
}

export function setNavView( view ) {
  return dispatch => {
    dispatch( setAttributes( {
      navView: view
    } ) );
  };
}

export function setDetailsView( view ) {
  return dispatch => {
    dispatch( setAttributes( {
      detailsView: view
    } ) );
  };
}

export function setDetailsTaxon( taxon, options = { } ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    const searchParams = {
      user_id: lifelist.user.id,
      order_by: "observed_on",
      order: "desc"
    };
    if ( taxon ) {
      if ( options.without_descendants ) {
        searchParams.exact_taxon_id = taxon.id;
      } else {
        searchParams.taxon_id = taxon.id;
      }
    }
    if ( taxon ) {
      searchParams.taxon_id = taxon.id;
    }
    dispatch( observationsSearch.initializeSearch( {
      method: "observations",
      action: "search",
      perPage: 50,
      force: true,
      maxResults: 500,
      searchParams
    } ) );
    dispatch( speciesSearch.initializeSearch( {
      method: "observations",
      action: "speciesCounts",
      perPage: 50,
      force: true,
      maxResults: 500,
      searchParams: {
        user_id: lifelist.user.id,
        taxon_id: taxon ? taxon.id : null
      }
    } ) );
    dispatch( setAttributes( {
      detailsTaxon: taxon,
      detailsTaxonObservations: null
    } ) );
    const newURLParams = Object.assign( $.deparam( window.location.search.replace( /^\?/, "" ) ) );
    if ( taxon ) {
      newURLParams.taxon_id = taxon.id;
    }
    history.replaceState( { }, "", `${window.location.pathname}?${$.param( newURLParams )}` );
  };
}

export function lookupCommonNamesSubPromise( ids, dispatch ) {
  return new Promise( resolve => {
    inatjs.taxa.search( { id: ids, is_active: "any", per_page: _.size( ids ) } ).then( response => {
      const commonNames = { };
      _.each( response.results, t => {
        commonNames[t.id] = t.preferred_common_name;
      } );
      dispatch( updateCommonNames( commonNames ) );
      resolve( );
    } );
  } );
}

export function lookupCommonNames( callback ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    const { openTaxa, children, taxa } = lifelist;
    let idsToLookup = [];
    if ( _.isEmpty( openTaxa ) ) {
      idsToLookup = children[0];
    } else {
      idsToLookup = openTaxa;
      _.each( openTaxa, id => {
        if ( children[id] ) {
          idsToLookup = idsToLookup.concat( children[id] );
        }
      } );
    }
    _.each( idsToLookup, id => {
      if ( children[id] ) {
        idsToLookup = idsToLookup.concat( children[id] );
      }
    } );
    idsToLookup = _.uniq( _.filter( idsToLookup, id => taxa[id] && !taxa[id].common_name_loaded ) );
    const chunks = _.chunk( idsToLookup, 100 );
    const promiseProducer = ( ) => {
      const chunk = chunks.shift( );
      if ( !chunk ) {
        return null;
      }
      return lookupCommonNamesSubPromise( chunk, dispatch );
    };
    const pool = new PromisePool( promiseProducer, 2 );
    pool.start( ).then( ( ) => {
      // tree was not reloading when only common names were changed
      dispatch( setAttributes( { updatedAt: new Date( ).getTime( ) } ) );
      if ( callback ) {
        callback( );
      }
    } );
  };
}

export function toggleTaxon( taxon, options = { } ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    if ( options.feature ) {
      const nextOpenIDs = [taxon.id];
      let branchID = taxon.id;
      while ( branchID ) {
        nextOpenIDs.push( branchID );
        branchID = lifelist.taxa[branchID] ? lifelist.taxa[branchID].parent_id : null;
      }
      dispatch( setAttributes( { openTaxa: nextOpenIDs } ) );
    } else if ( options.expand ) {
      _.each( lifelist.taxa, t => {
        if ( t.id === taxon.id || ( t.left > taxon.left && t.right < taxon.right ) ) {
          lifelist.openTaxa.push( t.id );
        }
      } );
      dispatch( setAttributes( { openTaxa: _.uniq( lifelist.openTaxa ) } ) );
      dispatch( lookupCommonNames( ) );
    } else if ( options.collapse ) {
      const toRemove = [];
      _.each( lifelist.taxa, t => {
        if ( t.left > taxon.left && t.right < taxon.right ) {
          toRemove.push( t.id );
        }
      } );
      dispatch( setAttributes( { openTaxa: _.difference( lifelist.openTaxa, toRemove ) } ) );
    } else if ( _.includes( lifelist.openTaxa, taxon.id ) ) {
      dispatch( setAttributes( { openTaxa: _.without( lifelist.openTaxa, taxon.id ) } ) );
    } else {
      dispatch( setAttributes( { openTaxa: lifelist.openTaxa.concat( [taxon.id] ) } ) );
      dispatch( lookupCommonNames( ) );
    }
  };
}

export function zoomToTaxon( taxonID ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    const taxon = lifelist.taxa[taxonID];
    if ( taxon ) {
      const ancestry = [taxon.id];
      let parent = lifelist.taxa[taxon.parent_id];
      while ( parent ) {
        ancestry.push( parent.id );
        parent = lifelist.taxa[parent.parent_id];
      }
      dispatch( setAttributes( { openTaxa: ancestry } ) );
      dispatch( lookupCommonNames( ) );
      dispatch( setDetailsTaxon( lifelist.taxa[taxon.id] ) );
    }
  };
}

export function fetchUser( user, options ) {
  return dispatch => {
    const urlParams = $.deparam( window.location.search.replace( /^\?/, "" ) );
    let searchParams = { user_id: user.id };
    let featuredTaxonID;
    if ( urlParams.filter ) {
      searchParams = Object.assign( { }, urlParams, searchParams );
      featuredTaxonID = searchParams.taxon_id;
      delete searchParams.taxon_id;
    } else if ( urlParams.taxon_id ) {
      featuredTaxonID = urlParams.taxon_id;
    }
    inatjs.observations.taxonomy( searchParams ).then( response => {
      const children = { };
      _.each( response.results, r => {
        if ( r.name === "Life" ) {
          return;
        }
        const parentID = ( r.parent_id === 48460 ) ? 0 : r.parent_id;
        children[parentID] = children[parentID] || [];
        children[parentID].push( r.id );
      } );
      const taxa = _.fromPairs( _.map( response.results, r => ( [r.id, r] ) ) );
      const descendantsRecursive = ( taxonID, ticker ) => {
        let descendantCount = 0;
        let idsToOpen = [];
        _.each( children[taxonID], childID => {
          let thisDescendantCount = 0;
          taxa[childID].left = ticker;
          ticker += 1;
          if ( children[childID] ) {
            const {
              childTicker,
              childDescendantCount,
              childIDsToOpen
            } = descendantsRecursive( childID, ticker );
            idsToOpen = childIDsToOpen;
            ticker = childTicker;
            thisDescendantCount += childDescendantCount;
            descendantCount += childDescendantCount;
            taxa[childID].descendantCount = thisDescendantCount;
          } else {
            descendantCount += 1;
            taxa[childID].descendantCount = 1;
          }
          taxa[childID].right = ticker;
          ticker += 1;
        } );
        if ( _.size( children[taxonID] ) === 1 ) {
          idsToOpen.push( children[taxonID][0] );
        } else {
          idsToOpen = [];
        }
        return {
          childTicker: ticker,
          childDescendantCount: descendantCount,
          childIDsToOpen: idsToOpen
        };
      };
      const { childIDsToOpen } = descendantsRecursive( 0, 0 );
      const leavesCount = _.sum( _.map( children[0], id => taxa[id].descendantCount ) );
      const observationsCount = _.sum( _.map( children[0], id => taxa[id].descendant_obs_count ) );
      dispatch( setAttributes( { leavesCount } ) );
      dispatch( setAttributes( { observationsCount } ) );
      dispatch( setAttributes( { children } ) );
      dispatch( setAttributes( { taxa } ) );
      dispatch( setAttributes( { user } ) );
      if ( !_.isEmpty( childIDsToOpen ) ) {
        dispatch( setAttributes( { openTaxa: childIDsToOpen } ) );
        dispatch( lookupCommonNames( options.callback ) );
        dispatch( setDetailsTaxon( taxa[_.first( childIDsToOpen )] ) );
      } else {
        if ( featuredTaxonID ) {
          dispatch( zoomToTaxon( featuredTaxonID ) );
        } else {
          dispatch( setDetailsTaxon( null ) );
        }
        dispatch( lookupCommonNames( options.callback ) );
      }
    } ).catch( e => console.log( e ) );
  };
}
