import _ from "lodash";
import inatjs from "inaturalistjs";
import {
  searchWrapper
} from "../../../shared/ducks/inat_api_duck";
import { updateSession } from "../../../shared/util";

const SET_ATTRIBUTES = "lifelists-show/SET_ATTRIBUTES";

const observationsSearch = searchWrapper( "observations" );
const speciesPlaceSearch = searchWrapper( "speciesPlace" );
const unobservedSpeciesSearch = searchWrapper( "unobservedSpecies" );

/* global inaturalist */
/* global LIFE_TAXON */
/* global MILESTONE_TAXON_IDS */
/* global INITIAL_PLACE */

const milestoneTaxa = _.keyBy( MILESTONE_TAXON_IDS );

const RANK_FILTER_RANK_LEVELS = {
  kingdoms: 70,
  phyla: 60,
  classes: 50,
  orders: 40,
  families: 30,
  genera: 20,
  species: 10
};

const NAV_VIEWS = [
  "list",
  "tree"
];

const DETAILS_VIEWS = [
  "species",
  "observations",
  "unobservedSpecies"
];

const TREE_MODES = [
  "simplified",
  "full_taxonomy"
];


const DEFAULT_STATE = {
  loading: true,
  user: null,
  openTaxa: [],
  simplifiedOpenTaxa: [],
  treeScrollIndex: 50,
  navView: "list",
  detailsView: "species",
  searchTaxon: null,
  detailsTaxon: null,
  detailsTaxonExact: false,
  detailsTaxonObservations: null,
  observationSort: "dateDesc",
  speciesPlaceFilter: null,
  listViewOpenTaxon: null,
  listViewRankFilter: "default",
  listViewScrollPage: 1,
  listViewPerPage: 100,
  listShowAncestry: true,
  treeSort: "taxonomic",
  treeMode: "simplified",
  treeIndent: true,
  speciesViewRankFilter: "leaves",
  speciesViewScrollPage: 1,
  speciesViewPerPage: 30,
  speciesViewSort: "obsDesc",
  initialized: false
};

export default function reducer( state = DEFAULT_STATE, action ) {
  switch ( action.type ) {
    case SET_ATTRIBUTES:
      return Object.assign( { }, state, action.attributes );
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

function updateBrowserStateHistory( initial = false ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    if ( !lifelist.initialized && !initial ) {
      return;
    }
    const browserState = { };
    const newURLParams = { };
    browserState.nav_view = lifelist.navView;
    browserState.details_view = lifelist.detailsView;
    browserState.tree_mode = lifelist.treeMode;
    if ( lifelist.navView !== DEFAULT_STATE.navView ) {
      newURLParams.view = lifelist.navView;
    }
    if ( lifelist.detailsView !== DEFAULT_STATE.detailsView ) {
      newURLParams.details_view = lifelist.detailsView;
    }
    if ( lifelist.treeMode !== DEFAULT_STATE.treeMode ) {
      newURLParams.tree_mode = lifelist.treeMode;
    }
    if ( lifelist.detailsTaxon ) {
      browserState.taxon_id = lifelist.detailsTaxon.id;
      newURLParams.taxon_id = lifelist.detailsTaxon.id;
    }
    if ( lifelist.searchTaxon ) {
      browserState.search_taxon_id = lifelist.searchTaxon.id;
    }
    if ( lifelist.speciesPlaceFilter ) {
      browserState.speciesPlaceFilter = {
        id: lifelist.speciesPlaceFilter.id,
        display_name: lifelist.speciesPlaceFilter.display_name
      };
      newURLParams.place_id = lifelist.speciesPlaceFilter.id;
    }
    if ( !_.isEqual( browserState, history.state ) ) {
      let newURL = window.location.pathname;
      if ( !_.isEmpty( newURLParams ) ) {
        newURL = `${window.location.pathname}?${$.param( newURLParams )}`;
      }
      if ( initial ) {
        history.replaceState( browserState, null, newURL );
      } else {
        history.pushState( browserState, null, newURL );
      }
    }
  };
}

export function fetchAllCommonNames( callback ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    const idsToLookup = _.uniq( _.map( _.filter(
      lifelist.taxa, t => !t.common_name_loaded
    ), t => t.id ) );
    if ( _.isEmpty( idsToLookup ) ) {
      return;
    }
    inatjs.taxa.lifelist_metadata( {
      observed_by_user_id: lifelist.user.login,
      locale: I18n.locale
    } ).then( response => {
      const commonNames = { };
      const photos = { };
      _.each( response.results, t => {
        commonNames[t.id] = t.preferred_common_name;
        photos[t.id] = t.default_photo;
      } );
      const modifiedTaxa = _.each( lifelist.taxa, t => {
        if ( t.id in commonNames ) {
          t.common_name_loaded = true;
          t.preferred_common_name = commonNames[t.id];
          t.default_photo = photos[t.id];
        }
        return t;
      } );
      dispatch( setAttributes( {
        taxa: modifiedTaxa,
        updatedAt: new Date( ).getTime( )
      } ) );
      if ( callback ) {
        callback( );
      }
    } );
  };
}

export function setNavView( view ) {
  return dispatch => {
    if ( !_.includes( NAV_VIEWS, view ) ) {
      return;
    }
    updateSession( { preferred_lifelist_nav_view: view } );
    dispatch( setAttributes( { navView: view } ) );
    dispatch( updateBrowserStateHistory( ) );
  };
}

export function setDetailsView( view ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    if ( !_.includes( DETAILS_VIEWS, view ) ) {
      return;
    }
    if ( lifelist.detailsView === view ) {
      return;
    }
    updateSession( { preferred_lifelist_details_view: view } );
    dispatch( setAttributes( { detailsView: view } ) );
    dispatch( updateBrowserStateHistory( ) );
    if ( view === "observations" ) {
      dispatch( observationsSearch.fetchFirstPage( ) );
    } else if ( view === "unobservedSpecies" ) {
      dispatch( unobservedSpeciesSearch.fetchFirstPage( ) );
    } else if ( view === "species" ) {
      dispatch( speciesPlaceSearch.fetchFirstPage( ) );
    }
  };
}

export function setListViewScrollPage( page ) {
  return dispatch => {
    dispatch( setAttributes( {
      listViewScrollPage: page
    } ) );
  };
}

export function setTreeScrollIndex( scrollIndex ) {
  return dispatch => {
    dispatch( setAttributes( {
      treeScrollIndex: scrollIndex
    } ) );
  };
}

export function setTreeMode( treeMode ) {
  return dispatch => {
    if ( !_.includes( TREE_MODES, treeMode ) ) {
      return;
    }
    updateSession( { preferred_lifelist_tree_mode: treeMode } );
    dispatch( setAttributes( { treeMode } ) );
    dispatch( updateBrowserStateHistory( ) );
  };
}

export function setTreeIndent( indent ) {
  return dispatch => {
    dispatch( setAttributes( { treeIndent: indent } ) );
  };
}

export function setListViewRankFilter( value ) {
  return dispatch => {
    dispatch( setAttributes( {
      listViewRankFilter: value,
      listViewScrollPage: 1
    } ) );
  };
}

export function setTreeSort( value ) {
  return dispatch => {
    dispatch( setAttributes( {
      treeSort: value,
      listViewScrollPage: 1
    } ) );
  };
}

export function setSpeciesViewRankFilter( value ) {
  return dispatch => {
    dispatch( setAttributes( {
      speciesViewRankFilter: value,
      speciesViewScrollPage: 1
    } ) );
  };
}

export function setSpeciesViewSort( value ) {
  return dispatch => {
    dispatch( setAttributes( {
      speciesViewSort: value
    } ) );
  };
}

export function setSpeciesViewScrollPage( page ) {
  return dispatch => {
    dispatch( setAttributes( {
      speciesViewScrollPage: page
    } ) );
  };
}

export function setListShowAncestry( show ) {
  return dispatch => {
    dispatch( setAttributes( {
      listShowAncestry: show
    } ) );
  };
}

export function updateObservationsSearch( reload = false ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    const searchParams = {
      user_id: lifelist.user.id,
      order_by: "observed_on",
      order: "desc",
      locale: I18n.locale
    };
    if ( lifelist.observationSort === "dateAsc" ) {
      searchParams.order = "asc";
    }
    if ( lifelist.detailsTaxon ) {
      if ( lifelist.detailsTaxonExact ) {
        searchParams.exact_taxon_id = lifelist.detailsTaxon.id;
      } else {
        searchParams.taxon_id = lifelist.detailsTaxon.id;
      }
    } else if ( lifelist.detailsTaxonExact ) {
      searchParams.without_taxon = true;
    }
    if ( lifelist.speciesPlaceFilter ) {
      searchParams.place_id = lifelist.speciesPlaceFilter.id;
    }
    dispatch( observationsSearch.initializeSearch( {
      method: "observations",
      action: "search",
      perPage: 50,
      force: true,
      maxResults: 500,
      searchParams
    } ) );
    if ( reload ) {
      dispatch( observationsSearch.fetchFirstPage( ) );
    }
  };
}

export function updateSpeciesPlaceSearch( reload = false ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    if ( lifelist.speciesPlaceFilter ) {
      dispatch( speciesPlaceSearch.initializeSearch( {
        method: "observations",
        action: "taxa",
        force: true,
        searchParams: {
          user_id: lifelist.user.id,
          place_id: lifelist.speciesPlaceFilter.id,
          locale: I18n.locale
        },
        resultsModify: results => {
          const allTaxa = {};
          _.each( results, r => {
            allTaxa[r.taxon_id] = allTaxa[r.taxon_id] || 0;
            allTaxa[r.taxon_id] += r.count;
            const lifelistTaxon = lifelist.taxa[r.taxon_id];
            if ( lifelistTaxon ) {
              _.each( lifelistTaxon.ancestors, a => {
                allTaxa[a] = allTaxa[a] || 0;
                allTaxa[a] += r.count;
              } );
            }
          } );
          return allTaxa;
        }
      } ) );
      if ( reload ) {
        dispatch( speciesPlaceSearch.fetchFirstPage( ) );
      }
    } else {
      dispatch( speciesPlaceSearch.initializeSearch( { } ) );
    }
    dispatch( setSpeciesViewScrollPage( 1 ) );
  };
}

export function updateUnobservedSpeciesSearch( reload = false ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    dispatch( unobservedSpeciesSearch.initializeSearch( {
      method: "observations",
      action: "speciesCounts",
      perPage: 50,
      force: true,
      maxResults: 500,
      searchParams: {
        unobserved_by_user_id: lifelist.user.id,
        taxon_id: lifelist.detailsTaxon ? lifelist.detailsTaxon.id : null,
        place_id: lifelist.speciesPlaceFilter ? lifelist.speciesPlaceFilter.id : null,
        quality_grade: "research",
        locale: I18n.locale
      }
    } ) );
    if ( reload ) {
      dispatch( unobservedSpeciesSearch.fetchFirstPage( ) );
    }
  };
}

export function setObservationSort( sort ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    dispatch( setAttributes( {
      observationSort: sort
    } ) );
    const searchParams = {
      user_id: lifelist.user.id,
      order_by: "observed_on",
      order: "desc"
    };
    if ( sort === "dateAsc" ) {
      searchParams.order = "asc";
    }
    dispatch( updateObservationsSearch( true ) );
  };
}

export function setSpeciesPlaceFilter( place ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    if ( ( !lifelist.speciesPlaceFilter && !place )
      || ( lifelist.speciesPlaceFilter && place && lifelist.speciesPlaceFilter.id === place.id ) ) {
      return;
    }
    dispatch( setAttributes( {
      speciesPlaceFilter: place
    } ) );
    dispatch( updateObservationsSearch( lifelist.detailsView === "observations" ) );
    dispatch( updateSpeciesPlaceSearch( lifelist.detailsView === "species" ) );
    dispatch( updateUnobservedSpeciesSearch( lifelist.detailsView === "unobservedSpecies" ) );
    dispatch( updateBrowserStateHistory( ) );
  };
}

export function setSearchTaxon( taxon ) {
  return dispatch => {
    dispatch( setAttributes( {
      searchTaxon: taxon
    } ) );
  };
}

export function setDetailsTaxon( taxon, options = { } ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    if ( lifelist.detailsTaxon === taxon
      && lifelist.detailsTaxonExact === options.without_descendants ) {
      return;
    }
    lifelist.detailsTaxon = taxon;
    lifelist.detailsTaxonExact = options.without_descendants;
    dispatch( setAttributes( {
      detailsTaxon: taxon,
      detailsTaxonExact: options.without_descendants,
      speciesViewScrollPage: 1
    } ) );
    if ( options.updateSearch || !taxon ) {
      dispatch( setSearchTaxon( taxon ) );
      dispatch( setAttributes( {
        listViewScrollPage: 1
      } ) );
    }
    dispatch( updateObservationsSearch( lifelist.detailsView === "observations" ) );
    dispatch( updateUnobservedSpeciesSearch( lifelist.detailsView === "unobservedSpecies" ) );
    const newURLParams = Object.assign( $.deparam( window.location.search.replace( /^\?/, "" ) ) );
    if ( taxon ) {
      newURLParams.taxon_id = taxon.id;
    } else {
      delete newURLParams.taxon_id;
    }
    // species view is filtered by a rank higher than what is being featured
    if ( taxon && RANK_FILTER_RANK_LEVELS[lifelist.speciesViewRankFilter]
      && taxon.rank_level <= RANK_FILTER_RANK_LEVELS[lifelist.speciesViewRankFilter] ) {
      const nextLowestRank = ( Math.floor( taxon.rank_level / 10 ) * 10 ) - 10;
      let newFilter = "leaves";
      if ( nextLowestRank > 20 ) {
        const nextHighestFilter = _.filter( _.toPairs( RANK_FILTER_RANK_LEVELS ),
          k => k[1] === nextLowestRank );
        if ( !_.isEmpty( nextHighestFilter ) ) {
          newFilter = nextHighestFilter[0][0];
        }
      }
      dispatch( setSpeciesViewRankFilter( newFilter ) );
    }
    dispatch( updateBrowserStateHistory( ) );
  };
}

export function toggleTaxon( taxon, options = { } ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    dispatch( setAttributes( {
      listViewOpenTaxon: taxon
    } ) );
    if ( !taxon ) { return; }
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
    } else if ( options.collapse ) {
      const toRemove = [];
      _.each( lifelist.taxa, t => {
        if ( t.left > taxon.left && t.right < taxon.right ) {
          toRemove.push( t.id );
        }
      } );
      toRemove.push( taxon.id );
      dispatch( setAttributes( { openTaxa: _.difference( lifelist.openTaxa, toRemove ) } ) );
    } else if ( _.includes( lifelist.openTaxa, taxon.id ) ) {
      dispatch( setAttributes( { openTaxa: _.without( lifelist.openTaxa, taxon.id ) } ) );
    } else {
      dispatch( setAttributes( { openTaxa: lifelist.openTaxa.concat( [taxon.id] ) } ) );
    }
  };
}

export function zoomToTaxon( taxonID, options = { } ) {
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
      dispatch( setDetailsTaxon( lifelist.taxa[taxon.id] ) );
      dispatch( setSearchTaxon( lifelist.taxa[taxon.id] ) );
      if ( options.detailsView ) {
        dispatch( setDetailsView( options.detailsView ) );
      } else if ( lifelist.detailsView === "unobservedSpecies" ) {
        dispatch( setDetailsView( "species" ) );
      }
    } else {
      dispatch( setDetailsTaxon( null ) );
    }
  };
}

export function updateWithHistoryState( state ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    dispatch( setAttributes( { initialized: false } ) );
    if ( state.nav_view !== lifelist.navView ) {
      dispatch( setNavView( state.nav_view ) );
    }
    if ( state.details_view !== lifelist.detailsView ) {
      dispatch( setDetailsView( state.details_view ) );
    }
    if ( state.tree_mode !== lifelist.treeMode ) {
      dispatch( setTreeMode( state.tree_mode ) );
    }
    dispatch( setDetailsTaxon( lifelist.taxa[state.taxon_id] ) );
    dispatch( setSpeciesPlaceFilter( state.speciesPlaceFilter ) );
    dispatch( setAttributes( { initialized: true }, { skipUpdateState: true } ) );
  };
}

export function fetchUser( user, options ) {
  return ( dispatch, getState ) => {
    const { config } = getState( );
    const urlParams = $.deparam( window.location.search.replace( /^\?/, "" ) );
    let searchParams = { user_id: user.id };
    let featuredTaxonID;
    if ( urlParams.filter ) {
      delete searchParams.user_id;
      searchParams = Object.assign( { }, urlParams, searchParams );
      featuredTaxonID = searchParams.taxon_id;
    } else if ( urlParams.taxon_id ) {
      featuredTaxonID = urlParams.taxon_id;
    }
    const simplifiedLeafParents = { };
    inatjs.observations.taxonomy( searchParams ).then( response => {
      const children = { };
      _.each( response.results, r => {
        if ( r.name === "Life" ) {
          return;
        }
        if ( r.parent_id === LIFE_TAXON.id ) {
          r.parent_id = 0;
        }
        children[r.parent_id] = children[r.parent_id] || [];
        children[r.parent_id].push( r.id );
      } );
      const taxa = _.fromPairs( _.map( response.results, r => ( [r.id, r] ) ) );
      const milestoneChildren = { };
      const descendantsRecursive = ( taxonID, ticker, milestoneTaxonID, ancestors = [] ) => {
        let descendantCount = 0;
        let hasMilestoneChildren;
        _.each( _.sortBy( children[taxonID], id => taxa[id].name ), childID => {
          let thisDescendantCount = 0;
          taxa[childID].left = ticker;
          ticker += 1;
          let nextMilestoneTaxonID = milestoneTaxonID;
          let milestoneLeaf = false;
          // milestone leaves are the next major rank below a major milestone taxon
          if ( !milestoneTaxa[childID]
            && milestoneTaxa[milestoneTaxonID]
            && taxa[childID].rank_level % 10 === 0
          ) {
            milestoneLeaf = true;
          }
          if ( milestoneTaxonID === 0 || milestoneTaxa[childID] || milestoneLeaf ) {
            nextMilestoneTaxonID = childID;
          }
          if ( children[childID] ) {
            const {
              childTicker,
              childDescendantCount,
              childHasMilestoneChildren
            } = descendantsRecursive( childID, ticker,
              nextMilestoneTaxonID, ancestors.concat( [childID] ) );
            ticker = childTicker;
            thisDescendantCount += childDescendantCount;
            descendantCount += childDescendantCount;
            hasMilestoneChildren = hasMilestoneChildren || childHasMilestoneChildren;
            taxa[childID].descendantCount = thisDescendantCount;
          } else {
            descendantCount += 1;
            taxa[childID].descendantCount = 1;
          }
          taxa[childID].right = ticker;
          taxa[childID].ancestors = ancestors;
          const isLeaf = ( taxa[childID].right === taxa[childID].left + 1 );
          if ( taxa[childID].rank_level === 70
            || ( isLeaf && taxa[childID].rank_level >= 10 )
            || milestoneTaxa[childID]
            || milestoneLeaf
            || taxa[childID].rank_level === 10
          ) {
            milestoneChildren[milestoneTaxonID] = milestoneChildren[milestoneTaxonID] || [];
            milestoneChildren[milestoneTaxonID].push( childID );
          }
          taxa[childID].milestoneParentID = milestoneTaxonID;
          if ( isLeaf ) {
            if ( milestoneTaxonID === 0 ) {
              // this is also a root node
              simplifiedLeafParents[childID] = true;
            } else {
              simplifiedLeafParents[milestoneTaxonID] = true;
            }
          }
          ticker += 1;
        } );
        return {
          childTicker: ticker,
          childDescendantCount: taxonID && taxa[taxonID].rank_level === 10 ? 1 : descendantCount,
          chilHasMilestoneChildren: hasMilestoneChildren
        };
      };
      delete taxa[LIFE_TAXON.id];
      descendantsRecursive( 0, 0, 0 );
      const leavesCount = _.sum( _.map( children[0], id => taxa[id].descendantCount ) );
      const observationsCount = _.sum( _.map( children[0], id => taxa[id].descendant_obs_count ) );
      dispatch( setAttributes( {
        leavesCount,
        observationsCount,
        milestoneChildren,
        children,
        taxa,
        user,
        simplifiedLeafParents: Object.keys( simplifiedLeafParents ),
        observationsWithoutTaxon: response.count_without_taxon
      } ) );
      if ( featuredTaxonID ) {
        dispatch( zoomToTaxon( featuredTaxonID, { skipUpdateState: true } ) );
      } else {
        // set open taxa to iconic taxa ancestors
        const openTaxa = _.compact( _.uniq( _.flatten( _.map( inaturalist.ICONIC_TAXA, t => {
          const iconicTaxon = taxa[t.id];
          return iconicTaxon ? iconicTaxon.ancestors : null;
        } ) ) ) );
        dispatch( setAttributes( { openTaxa } ) );
        dispatch( setDetailsTaxon( null ) );
      }
      if ( INITIAL_PLACE ) {
        dispatch( setSpeciesPlaceFilter( INITIAL_PLACE ) );
      }
      if ( urlParams.view ) {
        dispatch( setNavView( urlParams.view ) );
      } else if ( config.currentUser
        && config.currentUser.preferred_lifelist_nav_view !== DEFAULT_STATE.navView ) {
        dispatch( setNavView( config.currentUser.preferred_lifelist_nav_view ) );
      }
      if ( urlParams.details_view ) {
        dispatch( setDetailsView( urlParams.details_view ) );
      } else if ( config.currentUser
        && config.currentUser.preferred_lifelist_details_view !== DEFAULT_STATE.detailsView ) {
        dispatch( setDetailsView( config.currentUser.preferred_lifelist_details_view ) );
      }
      if ( urlParams.tree_mode ) {
        dispatch( setTreeMode( urlParams.tree_mode ) );
      } else if ( config.currentUser
        && config.currentUser.preferred_lifelist_tree_mode !== DEFAULT_STATE.treeMode ) {
        dispatch( setTreeMode( config.currentUser.preferred_lifelist_tree_mode ) );
      }

      dispatch( updateBrowserStateHistory( true ) );
      dispatch( fetchAllCommonNames( options.callback ) );
      dispatch( setAttributes( { initialized: true } ) );
    } ).catch( e => console.log( e ) );
  };
}
