import {
  UPDATE_SEARCH_PARAMS,
  RECEIVE_OBSERVATIONS,
  UPDATE_SEARCH_PARAMS_FROM_POP
} from "../actions";
import _ from "lodash";

const DEFAULT_PARAMS = {
  reviewed: false,
  verifiable: true,
  quality_grade: "needs_id",
  page: 1,
  per_page: 30,
  // This is a hack to get around our node API's cache control settings, since
  // it defaults to something, and we hit obs search repeatedly for stats. A
  // better approach might be to have a separate endpoints that delivers these
  // stats uncached, or disable cache-control when viewer_id is set or
  // something.
  ttl: -1
};

const normalizeParams = ( params ) => {
  const newParams = {};
  _.forEach( params, ( v, k ) => {
    // remove blank params
    if (
      v === null ||
      v === undefined ||
      ( typeof( v ) === "string" && v.length === 0 )
    ) {
      return;
    }
    let newValue = v;
    // coerce boolean-ish strings to booleans
    if ( newParams[k] === "true" ) newValue = true;
    else if ( newParams[k] === "false" ) newValue = false;
    // coarece integerish strings to numbers
    if (
      typeof( newValue ) === "string"
      && parseInt( newValue, 10 ) > 0
    ) {
      newValue = parseInt( newValue, 10 );
    }
    newParams[k] = newValue;
  } );
  return newParams;
};

const searchParamsReducer = ( state = DEFAULT_PARAMS, action ) => {
  let newState = state;
  switch ( action.type ) {
    case UPDATE_SEARCH_PARAMS:
      newState = Object.assign( {}, state, action.params );
      break;
    case UPDATE_SEARCH_PARAMS_FROM_POP:
      newState = Object.assign( {}, state, action.params );
      break;
    case RECEIVE_OBSERVATIONS:
      newState = Object.assign( {}, state, {
        page: action.page,
        per_page: action.perPage
      } );
      break;
    default:
      return state;
  }
  newState = normalizeParams( newState );
  if ( _.isEqual( state, newState ) ) {
    return state;
  }
  if ( action.type === UPDATE_SEARCH_PARAMS_FROM_POP ) {
    return newState;
  }
  const urlState = {};
  _.forEach( newState, ( v, k ) => {
    if ( DEFAULT_PARAMS[k] !== undefined && DEFAULT_PARAMS[k] === v ) {
      return;
    }
    urlState[k] = v;
  } );
  const title = `Identify: ${$.param( urlState )}`;
  const newUrl = [
    window.location.origin,
    window.location.pathname,
    _.isEmpty( urlState ) ? "" : "?",
    _.isEmpty( urlState ) ? "" : $.param( urlState )
  ].join( "" );
  history.pushState( urlState, title, newUrl );
  return newState;
};

export default searchParamsReducer;
export { normalizeParams };
