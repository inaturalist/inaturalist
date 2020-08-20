import _ from "lodash";
import inatjs from "inaturalistjs";

const SET_ATTRIBUTES = "inatapiduck/search/SET_ATTRIBUTES";
const INITIALIZE_SEARCH = "inatapiduck/search/INITIALIZE_SEARCH";

export const DEFAULT_STATE = {
  method: null,
  action: null,
  searchParams: null,
  loaded: false,
  loading: false,
  searchResponse: null,
  perPage: 50,
  maxResults: 200,
  pagesFetched: null,
  scrollIndex: null,
  searchError: null,
  resultsMap: null,
  resultsModify: null,
  hasMore: false
};

function hasMore( instanceState ) {
  if ( !instanceState.searchResponse ) {
    return false;
  }
  const { results } = instanceState.searchResponse;
  return results
    && results.length >= instanceState.scrollIndex
    && instanceState.scrollIndex < instanceState.maxResults
    && instanceState.scrollIndex < instanceState.searchResponse.total_results;
}

export default function reducer( state = { }, action ) {
  let newState;
  let newInstanceState;
  switch ( action.type ) {
    case SET_ATTRIBUTES:
      if ( !_.get( state, action.searchKey ) ) {
        return state;
      }
      newState = Object.assign( { }, state );
      newInstanceState = Object.assign( { }, _.get( state, action.searchKey ), action.attributes );
      _.setWith( newState, action.searchKey, newInstanceState, Object );
      newInstanceState.hasMore = hasMore( newInstanceState );
      return newState;
    case INITIALIZE_SEARCH:
      newState = Object.assign( { }, state );
      newInstanceState = Object.assign( { }, DEFAULT_STATE, action.attributes );
      _.setWith( newState, action.searchKey, newInstanceState, Object );
      return newState;
    default:
  }
  return state;
}

function setAttributes( searchKey, attributes ) {
  return {
    type: SET_ATTRIBUTES,
    searchKey,
    attributes
  };
}

function initialize( searchKey, attributes ) {
  return {
    type: INITIALIZE_SEARCH,
    searchKey,
    attributes
  };
}

function initializeSearch( searchKey, options = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const instanceState = _.get( state.inatAPI, searchKey );
    if ( instanceState && instanceState.loaded && !options.force ) {
      return;
    }
    dispatch( initialize( searchKey, options ) );
  };
}

function fetchFirstPage( searchKey, options = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const instanceState = _.get( state.inatAPI, searchKey );
    if ( !instanceState || instanceState.searchParams === null || !instanceState.method
      || !instanceState.action || ( instanceState.loaded && !options.force ) ) {
      return;
    }
    dispatch( setAttributes( searchKey, {
      loaded: false,
      loading: true
    } ) );
    const queryParams = Object.assign( { }, instanceState.searchParams, {
      per_page: instanceState.perPage
    } );
    inatjs[instanceState.method][instanceState.action]( queryParams ).then( response => {
      if ( instanceState.resultsMap ) {
        _.each( response.results, instanceState.resultsMap );
      }
      if ( instanceState.resultsModify ) {
        response.results = instanceState.resultsModify( response.results );
      }
      const nextAttrs = {
        loaded: true,
        loading: false,
        searchResponse: response,
        pagesFetched: 1,
        searchError: null,
        scrollIndex: options.firstPageSize || instanceState.perPage
      };
      dispatch( setAttributes( searchKey, nextAttrs ) );
    } ).catch( e => {
      console.log( ["iNatAPIDuckError:", e] );
      dispatch( setAttributes( searchKey, {
        searchError: e
      } ) );
    } );
  };
}

function fetchNextPage( searchKey ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const instanceState = _.get( state.inatAPI, searchKey );
    if ( !instanceState
      || !instanceState.loaded
      || instanceState.scollIndex >= instanceState.maxResults
      || instanceState.scollIndex >= instanceState.searchResponse.total_results ) {
      return null;
    }
    const loaded = instanceState.searchResponse.results.length;
    const nextScrollIndex = instanceState.scrollIndex + instanceState.perPage;
    if ( nextScrollIndex <= loaded
      || instanceState.searchResponse.results.length >= instanceState.searchResponse.total_results ) {
      dispatch( setAttributes( searchKey, { scrollIndex: nextScrollIndex } ) );
      return null;
    }
    const queryParams = Object.assign( { }, instanceState.searchParams, {
      per_page: instanceState.perPage,
      page: instanceState.pagesFetched + 1
    } );
    dispatch( setAttributes( searchKey, {
      loaded: false,
      loading: true
    } ) );
    return inatjs[instanceState.method][instanceState.action]( queryParams ).then( response => {
      if ( instanceState.resultsMap ) {
        _.each( response.results, instanceState.resultsMap );
      }
      instanceState.searchResponse.results = instanceState
        .searchResponse.results.concat( response.results );
      const nextAttrs = {
        loaded: true,
        loading: false,
        searchResponse: instanceState.searchResponse,
        pagesFetched: instanceState.pagesFetched + 1,
        scrollIndex: nextScrollIndex
      };
      dispatch( setAttributes( searchKey, nextAttrs ) );
    } ).catch( e => console.log( e ) );
  };
}

export function searchWrapper( searchKey ) {
  return {
    initializeSearch: ( ...args ) => initializeSearch( searchKey, ...args ),
    fetchFirstPage: ( ...args ) => fetchFirstPage( searchKey, ...args ),
    fetchNextPage: ( ) => fetchNextPage( searchKey )
  };
}
