import _ from "lodash";
import inatjs from "inaturalistjs";
import {
  searchWrapper
} from "../../../shared/ducks/inat_api_duck";

const SET_ATTRIBUTES = "lifelists-show/SET_ATTRIBUTES";

const observationsSearch = searchWrapper( "observations" );
const speciesPlaceSearch = searchWrapper( "speciesPlace" );
const unobservedSpeciesSearch = searchWrapper( "unobservedSpecies" );

/* global MILESTONE_TAXON_IDS */
const milestoneTaxa = _.keyBy( MILESTONE_TAXON_IDS );

const RANK_FILTER_RANK_LEVELS = {
  kingdoms: 70,
  phylums: 60,
  classes: 50,
  orders: 40,
  families: 30,
  genera: 20,
  species: 10
};

export default function reducer( state = {
  loading: true,
  user: null,
  openTaxa: [],
  simplifiedOpenTaxa: [],
  treeScrollIndex: 50,
  navView: "simplified",
  detailsView: "species",
  detailsTaxon: null,
  detailsTaxonExact: false,
  detailsTaxonObservations: null,
  observationSort: "dateDesc",
  speciesPlaceFilter: null,
  listViewOpenTaxon: null,
  listViewRankFilter: "default",
  listViewScrollPage: 1,
  listViewPerPage: 100,
  treeSort: "taxonomic",
  treeMode: "tree",
  treeIndent: true,
  speciesViewRankFilter: "leaves",
  speciesViewScrollPage: 1,
  speciesViewPerPage: 100,
  speciesViewSort: "obsDesc"

}, action ) {
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
export function fetchAllCommonNames( callback ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    const idsToLookup = _.uniq( _.map( _.filter(
      lifelist.taxa, t => !t.common_name_loaded
    ), t => t.id ) );
    if ( _.isEmpty( idsToLookup ) ) {
      return;
    }
    inatjs.taxa.lifelist_metadata(
      { observed_by_user_id: lifelist.user.login }
    ).then( response => {
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
    if ( view === "list" ) {
      dispatch( fetchAllCommonNames( ) );
    }
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
    dispatch( setAttributes( { treeMode } ) );
  };
}

export function setTreeIndent( indent ) {
  return dispatch => {
    dispatch( setAttributes( { treeIndent: indent } ) );
  };
}

export function setListViewOpenTaxon( taxon ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    dispatch( setAttributes( {
      listViewOpenTaxon: taxon
    } ) );
    dispatch( setListViewScrollPage( 1 ) );
    if ( lifelist.treeMode === "list" && taxon ) {
      const ancestry = [taxon.id];
      let parent = lifelist.taxa[taxon.parent_id];
      while ( parent ) {
        ancestry.push( parent.id );
        parent = lifelist.taxa[parent.parent_id];
      }
      dispatch( setAttributes( { openTaxa: ancestry } ) );
      dispatch( setAttributes( { simplifiedOpenTaxa: ancestry } ) );
    }
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

export function updateObservationsSearch( reload = false ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    const searchParams = {
      user_id: lifelist.user.id,
      order_by: "observed_on",
      order: "desc"
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
      searchParams.identified = false;
    }
    if ( lifelist.speciesPlaceFilter ) {
      searchParams.place_id = lifelist.speciesPlaceFilter;
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
          place_id: lifelist.speciesPlaceFilter
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
        place_id: lifelist.speciesPlaceFilter,
        quality_grade: "research",
        lrank: "species"
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
    dispatch( updateObservationsSearch( ) );
  };
}

export function setSpeciesPlaceFilter( placeID ) {
  return ( dispatch, getState ) => {
    const { lifelist } = getState( );
    dispatch( setAttributes( {
      speciesPlaceFilter: placeID
    } ) );
    dispatch( updateObservationsSearch( lifelist.detailsView === "observations" ) );
    dispatch( updateSpeciesPlaceSearch( lifelist.detailsView === "species" ) );
    dispatch( updateUnobservedSpeciesSearch( lifelist.detailsView === "unobservedSpecies" ) );
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
    dispatch( updateObservationsSearch( lifelist.detailsView === "observations" ) );
    dispatch( updateUnobservedSpeciesSearch( lifelist.detailsView === "unobservedSpecies" ) );
    const newURLParams = Object.assign( $.deparam( window.location.search.replace( /^\?/, "" ) ) );
    if ( taxon ) {
      newURLParams.taxon_id = taxon.id;
    } else {
      delete newURLParams.taxon_id;
    }
    if ( _.isEmpty( newURLParams ) ) {
      history.replaceState( { }, "", `${window.location.pathname}` );
    } else {
      history.replaceState( { }, "", `${window.location.pathname}?${$.param( newURLParams )}` );
    }
    dispatch( setListViewOpenTaxon( taxon ) );
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
      dispatch( setListViewOpenTaxon( lifelist.taxa[taxon.id] ) );
      if ( options.detailsView ) {
        dispatch( setDetailsView( options.detailsView ) );
      } else if ( lifelist.detailsView === "unobservedSpecies" ) {
        dispatch( setDetailsView( "species" ) );
      }
      dispatch( setDetailsTaxon( lifelist.taxa[taxon.id] ) );
    }
  };
}


export function fetchUser( user, options ) {
  /* global LIFE_TAXON */
  return dispatch => {
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
        let idsToOpen = [];
        let hasMilestoneChildren;
        _.each( _.sortBy( children[taxonID], id => taxa[id].name ), childID => {
          let thisDescendantCount = 0;
          taxa[childID].left = ticker;
          ticker += 1;
          let nextMilestoneTaxonID = milestoneTaxonID;
          let milestoneLeaf = false;
          if ( !milestoneTaxa[childID]
            && milestoneTaxa[milestoneTaxonID]
            && taxa[childID].rank_level % 10 === 0
          ) {
            milestoneLeaf = true;
          }
          if ( taxa[childID].rank_level === 70
            || taxa[childID].rank_level === 10
            || milestoneTaxa[childID]
            || milestoneLeaf
          ) {
            milestoneChildren[milestoneTaxonID] = milestoneChildren[milestoneTaxonID] || [];
            milestoneChildren[milestoneTaxonID].push( childID );
          } else {
            taxa[childID].nearestMilestoneTaxonID = milestoneTaxonID;
          }
          if ( milestoneTaxonID === 0 || milestoneTaxa[childID] || milestoneLeaf ) {
            nextMilestoneTaxonID = childID;
          }
          if ( children[childID] ) {
            const {
              childTicker,
              childDescendantCount,
              childIDsToOpen,
              childHasMilestoneChildren
            } = descendantsRecursive( childID, ticker,
              nextMilestoneTaxonID, ancestors.concat( [childID] ) );
            idsToOpen = idsToOpen.concat( childIDsToOpen );
            ticker = childTicker;
            thisDescendantCount += childDescendantCount;
            descendantCount += childDescendantCount;
            hasMilestoneChildren = hasMilestoneChildren || childHasMilestoneChildren;
            taxa[childID].descendantCount = thisDescendantCount;
            if ( milestoneTaxa[childID] && !milestoneLeaf ) {
              idsToOpen.push( childID );
            }
          } else {
            descendantCount += 1;
            taxa[childID].descendantCount = 1;
          }
          taxa[childID].right = ticker;
          taxa[childID].ancestors = ancestors;
          ticker += 1;
        } );
        return {
          childTicker: ticker,
          childDescendantCount: descendantCount,
          childIDsToOpen: idsToOpen,
          chilHasMilestoneChildren: hasMilestoneChildren
        };
      };
      delete taxa[LIFE_TAXON.id];
      const { childIDsToOpen } = descendantsRecursive( 0, 0, 0 );
      const leavesCount = _.sum( _.map( children[0], id => taxa[id].descendantCount ) );
      const observationsCount = _.sum( _.map( children[0], id => taxa[id].descendant_obs_count ) );
      dispatch( setAttributes( {
        leavesCount,
        observationsCount,
        milestoneChildren,
        children,
        taxa,
        user,
        observationsWithoutTaxon: response.count_without_taxon
      } ) );
      if ( _.isEmpty( childIDsToOpen ) ) {
        dispatch( setAttributes( { openTaxa: _.map( _.keys( taxa ), i => Number( i ) ) } ) );
      } else {
        dispatch( setAttributes( { openTaxa: childIDsToOpen } ) );
      }
      if ( featuredTaxonID ) {
        dispatch( zoomToTaxon( featuredTaxonID ) );
      } else {
        dispatch( setDetailsTaxon( null, { reloadSearch: true } ) );
      }
      dispatch( fetchAllCommonNames( options.callback ) );
    } ).catch( e => console.log( e ) );
  };
}
