import { UPDATE_SEARCH_PARAMS, RECEIVE_OBSERVATIONS } from "../actions";

const searchParamsReducer = ( state = {
  reviewed: false,
  verifiable: true,
  quality_grade: "needs_id",
  // This is a hack to get around our node API's cache control settings, since
  // it defaults to something, and we hit obs search repeatedly for stats. A
  // better approach might be to have a separate endpoints that delivers these
  // stats uncached, or disable cache-control when viewer_id is set or
  // something.
  ttl: -1
}, action ) => {
  if ( action.type === UPDATE_SEARCH_PARAMS ) {
    return Object.assign( {}, state, action.params );
  } else if ( action.type === RECEIVE_OBSERVATIONS ) {
    return Object.assign( {}, state, {
      page: action.page,
      perPage: action.perPage
    } );
  }
  return state;
};

export default searchParamsReducer;
