import _ from "lodash";
import inatjs from "inaturalistjs";
import utf8 from "utf8";

const SET_QUERIES = "observations-compare/compare/SET_QUERIES";
const SET_TAB = "observations-compare/compare/SET_TAB";
const SET_TAXA = "observations-compare/compare/SET_TAXA";
const SET_TAXON_FREQUENCIES = "observations-compare/compare/SET_TAXON_FREQUENCIES";
const ADD_QUERY = "observations-compare/compare/ADD_QUERY";
const REMOVE_QUERY_AT_INDEX = "observations-compare/compare/REMOVE_QUERY_AT_INDEX";
const UPDATE_QUERY_AT_INDEX = "observations-compare/compare/UPDATE_QUERY_AT_INDEX";
const SORT_FREQUENCIES_BY_INDEX = "observations-compare/compare/SORT_FREQUENCIES_BY_INDEX";
const SET_TAXON_FILTER = "observations-compare/compare/SET_TAXON_FILTER";
const SET_BOUNDS = "observations-compare/compare/SET_BOUNDS";
const SET_TOTAL_TAXON_COUNTS = "observations-compare/compare/SET_TOTAL_TAXON_COUNTS";
const MOVE_QUERY = "observations-compare/compare/MOVE_QUERY";
const SET_MAP_LAYOUT = "observations-compare/compare/SET_MAP_LAYOUT";

const setUrl = state => {
  const json = JSON.stringify( _.pick( state, [
    "queries",
    "tab",
    "taxonFilter",
    "taxonFrequenciesSortIndex",
    "taxonFrequenciesSortOrder",
    "mapLayout"
  ] ) );
  const bytes = utf8.encode( json );
  const encoded = btoa( bytes );
  const urlState = { s: encoded };
  const title = `Compare ${encoded}`;
  const newUrl = [
    window.location.origin,
    window.location.pathname,
    "?",
    $.param( urlState )
  ].join( "" );
  history.pushState( urlState, title, newUrl );
};

export const DEFAULT_STATE = {
  tab: "species",
  queries: [
    {
      name: "Query 1",
      params: `year=${( new Date( ) ).getYear( ) + 1900 - 1}`
    },
    {
      name: "Query 2",
      params: `year=${( new Date( ) ).getYear( ) + 1900}`
    }
  ],
  taxa: {},
  taxonFrequencies: [],
  taxonFrequenciesSortIndex: 0,
  taxonFrequenciesSortOrder: "asc",
  totalTaxonCounts: [],
  numTaxaInCommon: 0,
  numTaxaNotInCommon: 0,
  numTaxaUnique: 0,
  taxonFilter: "none",
  bounds: {
    swlat: -80,
    swlng: -170,
    nelat: 80,
    nelng: 170
  },
  mapLayout: "combined"
};

export default function reducer( state = DEFAULT_STATE, action ) {
  const newState = _.cloneDeep( state );
  switch ( action.type ) {
    case SET_TAB:
      newState.tab = action.tab;
      setUrl( newState );
      break;
    case SET_QUERIES: {
      newState.queries = action.queries;
      setUrl( newState );
      break;
    }
    case SET_TAXA:
      newState.taxa = action.taxa;
      break;
    case SET_TAXON_FREQUENCIES:
      newState.taxonFrequencies = action.taxonFrequencies;
      break;
    case ADD_QUERY:
      newState.queries.push( {
        name: `Query ${newState.queries.length + 1}`,
        params: `year=${( new Date( ) ).getYear( ) + 1900}`
      } );
      setUrl( newState );
      break;
    case REMOVE_QUERY_AT_INDEX:
      newState.queries = newState.queries.filter( ( q, i ) => i !== action.index );
      setUrl( newState );
      break;
    case UPDATE_QUERY_AT_INDEX:
      newState.queries[action.index] = Object.assign( { }, newState.queries[action.index], action.updates );
      setUrl( newState );
      break;
    case SORT_FREQUENCIES_BY_INDEX:
      newState.taxonFrequenciesSortIndex = action.index;
      newState.taxonFrequenciesSortOrder = action.order;
      setUrl( newState );
      break;
    case SET_TAXON_FILTER:
      newState.taxonFilter = action.filter;
      setUrl( newState );
      break;
    case SET_BOUNDS:
      newState.bounds = action.bounds;
      break;
    case SET_TOTAL_TAXON_COUNTS:
      newState.totalTaxonCounts = action.counts;
      break;
    case MOVE_QUERY: {
      const query = newState.queries.splice( action.index, 1 )[0];
      newState.queries.splice( action.newIndex, 0, query );
      setUrl( newState );
      break;
    }
    case SET_MAP_LAYOUT:
      newState.mapLayout = action.mapLayout;
      setUrl( newState );
      break;
    default:
      // nothing to see here
  }
  newState.taxonFrequencies = _.sortBy( newState.taxonFrequencies, row => {
    if ( newState.taxonFrequenciesSortIndex === 0 ) {
      const taxon = newState.taxa[row[0]];
      if ( taxon ) {
        return `${taxon.ancestor_ids.join( "/" )}/0/${taxon.name}`;
      }
      return "";
    }
    const sortVal = parseInt( row[newState.taxonFrequenciesSortIndex], 0 );
    if ( newState.taxonFrequenciesSortOrder === "asc" ) {
      return sortVal;
    }
    return sortVal * -1;
  } );
  newState.numTaxaNotInCommon = 0;
  newState.numTaxaInCommon = 0;
  newState.numTaxaUnique = 0;
  _.forEach( newState.taxonFrequencies, row => {
    const frequencies = row.slice( 1, row.length );
    if ( frequencies.indexOf( "?" ) >= 0 ) {
      return;
    }
    if ( frequencies.indexOf( 0 ) >= 0 ) {
      newState.numTaxaNotInCommon += 1;
    } else {
      newState.numTaxaInCommon += 1;
    }
    if ( _.filter( frequencies, f => f > 0 ).length === 1 ) {
      newState.numTaxaUnique += 1;
    }
  } );
  return newState;
}

export function setTab( tab ) {
  return {
    type: SET_TAB,
    tab
  };
}

export function setQueries( queries ) {
  return {
    type: SET_QUERIES,
    queries
  };
}

export function setTaxa( taxa ) {
  return {
    type: SET_TAXA,
    taxa
  };
}

export function setTaxonFrequencies( taxonFrequencies ) {
  return {
    type: SET_TAXON_FREQUENCIES,
    taxonFrequencies
  };
}

export function setBounds( bounds ) {
  return {
    type: SET_BOUNDS,
    bounds
  };
}

export function setTotalTaxonCounts( counts ) {
  return {
    type: SET_TOTAL_TAXON_COUNTS,
    counts
  };
}

export function moveQuery( index, newIndex ) {
  return {
    type: MOVE_QUERY,
    index,
    newIndex
  };
}

export function setMapLayout( mapLayout ) {
  return {
    type: SET_MAP_LAYOUT,
    mapLayout
  };
}

export function fetchTaxa( ) {
  return ( dispatch, getState ) => {
    const s = getState( ).compare;
    Promise.all(
      s.queries.map( query => inatjs.observations.speciesCounts( $.deparam( query.params ) ) )
    ).catch( e => {
      // const msg = JSON.parse( e.message ).error || "Something truly awful has happened.";
      dispatch( setTaxa( {} ) );
      dispatch( setTaxonFrequencies( [] ) );
      // alert( msg );
    } ).then( responses => {
      const taxa = {};
      const taxonFrequencies = {};
      const totalTaxonCounts = responses.map( r => r.total_results );
      dispatch( setTotalTaxonCounts( totalTaxonCounts ) );
      _.forEach( responses, ( response, queryIndex ) => {
        _.forEach( response.results, result => {
          if ( !taxa[result.taxon.id] ) {
            taxa[result.taxon.id] = result.taxon;
          }
          taxonFrequencies[result.taxon.id] = taxonFrequencies[result.taxon.id] || s.queries.map( ( ) => "?" );
          taxonFrequencies[result.taxon.id][queryIndex] = result.count;
        } );
      } );

      // Ffill in values for higher level taxa when the leaf for a given a query
      // is more specific, e.g. query 1 has Homo and query 2 has Homo sapiens,
      // so they should both have Homo. Unfortunately this does not work in
      // situations where whery 2 has Homo AND Homo sapiens but ignores the Homo
      // records b/c they're not leaves, i.e. it will still show commonality but
      // counts will be off.
      _.forEach( taxonFrequencies, ( values, taxonID ) => {
        _.forEach( totalTaxonCounts, ( totalCount, queryIndex ) => {
          if ( totalCount <= 500 && taxonFrequencies[taxonID][queryIndex] === "?" ) {
            taxonFrequencies[taxonID][queryIndex] = 0;
          }
        } );
        const taxon = taxa[taxonID];
        const ancestorIDs = _.filter( taxon.ancestor_ids, aid => aid !== parseInt( taxonID, 0 ) );
        _.forEach( ancestorIDs, ancestorID => {
          if ( taxonFrequencies[ancestorID] ) {
            _.forEach( taxonFrequencies[ancestorID], ( ancestorVal, i ) => {
              taxonFrequencies[ancestorID][i] = ( parseInt( ancestorVal, 0 ) || 0 ) + ( parseInt( values[i], 0 ) || 0 );
            } );
          }
        } );
      } );
      

      dispatch( setTaxa( taxa ) );
      const taxonFrequenciesArray = _.map( taxonFrequencies, ( frequencies, taxonID ) => _.flatten( [taxonID, frequencies] ) );
      dispatch( setTaxonFrequencies( taxonFrequenciesArray ) );
    } );
  };
}

export function addQuery( ) {
  return {
    type: ADD_QUERY
  };
}

export function removeQueryAtIndex( index ) {
  return {
    type: REMOVE_QUERY_AT_INDEX,
    index
  };
}

export function updateQueryAtIndex( index, updates ) {
  return {
    type: UPDATE_QUERY_AT_INDEX,
    index,
    updates
  };
}

export function fetchBounds( ) {
  return ( dispatch, getState ) => {
    const s = getState( ).compare;
    if ( !s.queries || s.queries.length === 0 ) {
      return;
    }
    const promises = s.queries.map( query => {
      const params = $.deparam( query.params );
      params.per_page = 1;
      params.return_bounds = true;
      return inatjs.observations.search( params );
    } );
    Promise.all( promises ).catch( e => {
      console.log( "[DEBUG] e: ", e );
    } ).then( responses => {
      const bounds = new google.maps.LatLngBounds( );
      _.forEach( responses, response => {
        bounds.extend( {
          lat: response.total_bounds.swlat,
          lng: response.total_bounds.swlng
        } );
        bounds.extend( {
          lat: response.total_bounds.nelat,
          lng: response.total_bounds.nelng
        } );
      } );
      dispatch( setBounds( {
        swlat: bounds.getSouthWest( ).lat( ),
        swlng: bounds.getSouthWest( ).lng( ),
        nelat: bounds.getNorthEast( ).lat( ),
        nelng: bounds.getNorthEast( ).lng( )
      } ) );
    } );
  };
}

export function fetchDataForTab( tab ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const chosenTab = tab || s.compare.tab;
    if ( chosenTab === "species" ) {
      dispatch( fetchTaxa( ) );
    } else if ( chosenTab === "map" ) {
      dispatch( fetchBounds( ) );
    }
  };
}

export function chooseTab( tab ) {
  return dispatch => {
    dispatch( setTab( tab ) );
    dispatch( fetchDataForTab( tab ) );
  };
}

export function sortFrequenciesByIndex( index, order = "asc" ) {
  return {
    type: SORT_FREQUENCIES_BY_INDEX,
    index,
    order
  };
}

export function setTaxonFilter( filter ) {
  return {
    type: SET_TAXON_FILTER,
    filter
  };
}
