import _ from "lodash";
import inatjs from "inaturalistjs";
import { setConfig } from "../../../shared/ducks/config";

const SET_QUERIES = "observations-compare/compare/SET_QUERIES";
const SET_TAXA = "observations-compare/compare/SET_TAXA";
const SET_TAXON_FREQUENCIES = "observations-compare/compare/SET_TAXON_FREQUENCIES";
const ADD_QUERY = "observations-compare/compare/ADD_QUERY";
const REMOVE_QUERY_AT_INDEX = "observations-compare/compare/REMOVE_QUERY_AT_INDEX";
const UPDATE_QUERY_AT_INDEX = "observations-compare/compare/UPDATE_QUERY_AT_INDEX";
const SORT_FREQUENCIES_BY_INDEX = "observations-compare/compare/SORT_FREQUENCIES_BY_INDEX";
const SET_TAXON_FILTER = "observations-compare/compare/SET_TAXON_FILTER";

export default function reducer( state = {
  tab: "species",
  queries: [
    {
      name: "Query 1",
      params: "user_id=kueda"
    },
    {
      name: "Query 2",
      params: "user_id=marceline"
    }
  ],
  taxa: {},
  taxonFrequencies: [],
  taxonFrequenciesSortIndex: 0,
  taxonFrequenciesSortOrder: "asc",
  numTaxaInCommon: 0,
  numTaxaDistinct: 0,
  taxonFilter: "none"
}, action ) {
  const newState = _.cloneDeep( state );
  switch ( action.type ) {
    case SET_QUERIES:
      newState.queries = action.queries;
      break;
    case SET_TAXA:
      newState.taxa = action.taxa;
      break;
    case SET_TAXON_FREQUENCIES:
      newState.taxonFrequencies = action.taxonFrequencies;
      break;
    case ADD_QUERY:
      newState.queries.push( {
        name: `Query ${newState.queries.length + 1}`,
        params: "taxon_id=-1"
      } );
      break;
    case REMOVE_QUERY_AT_INDEX:
      newState.queries = newState.queries.filter( ( q, i ) => i !== action.index );
      break;
    case UPDATE_QUERY_AT_INDEX:
      newState.queries[action.index] = Object.assign( { }, newState.queries[action.index], action.updates );
      break;
    case SORT_FREQUENCIES_BY_INDEX:
      newState.taxonFrequenciesSortIndex = action.index;
      newState.taxonFrequenciesSortOrder = action.order;
      break;
    case SET_TAXON_FILTER:
      newState.taxonFilter = action.filter;
      break;
    default:
      // nothing to see here
  }
  newState.taxonFrequencies = _.sortBy( newState.taxonFrequencies, row => {
    if ( newState.taxonFrequenciesSortIndex === 0 ) {
      const taxon = newState.taxa[row[0]];
      if ( taxon ) {
        return `${taxon.ancestor_ids.join( "/" )}/${taxon.name}`;
      }
      return "";
    }
    const sortVal = row[newState.taxonFrequenciesSortIndex] || 0;
    if ( newState.taxonFrequenciesSortOrder === "asc" ) {
      return sortVal;
    }
    return sortVal * -1;
  } );
  newState.numTaxaDistinct = 0;
  newState.numTaxaInCommon = 0;
  _.forEach( newState.taxonFrequencies, row => {
    const frequencies = row.slice( 1, row.length );
    if ( frequencies.indexOf( 0 ) >= 0 ) {
      newState.numTaxaDistinct += 1;
    } else {
      newState.numTaxaInCommon += 1;
    }
  } );
  return newState;
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
      _.forEach( responses, ( response, queryIndex ) => {
        _.forEach( response.results, result => {
          if ( !taxa[result.taxon.id] ) {
            taxa[result.taxon.id] = result.taxon;
          }
          taxonFrequencies[result.taxon.id] = taxonFrequencies[result.taxon.id] || s.queries.map( ( ) => 0 );
          taxonFrequencies[result.taxon.id][queryIndex] = result.count;
        } );
      } );

      // not quite working, but trying to fill in values for higher level taxa
      // when the leaf for a given a query is more specific, e.g. query 1 has
      // Homo and query 2 as Homo sapiens, so they should both have Homo
      // // for each row
      // _.forEach( taxonFrequencies, ( values, taxonID ) => {
      //   const taxon = taxa[taxonID];
      //   const ancestorIDs = _.filter( taxon.ancestor_ids, aid => aid !== taxonID );
      //   _.forEach( ancestorIDs, ancestorID => {
      //     if ( taxonFrequencies[ancestorID] ) {
      //       _.forEach( taxonFrequencies[ancestorID], ( ancestorVal, i ) => {
      //         taxonFrequencies[ancestorID][i] = ancestorVal + values[i];
      //       } );
      //     }
      //   } );
      // } );
      

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

export function fetchDataForTab( tab ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const chosenTab = tab || s.config.chosenTab;
    if ( chosenTab === "species" ) {
      dispatch( fetchTaxa( ) );
    }
  };
}

export function chooseTab( tab ) {
  return dispatch => {
    dispatch( setConfig( { chosenTab: tab } ) );
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
