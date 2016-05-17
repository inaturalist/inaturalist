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
  iconic_taxa: [],
  order_by: "observations.id",
  order: "desc",
  // This is a hack to get around our node API's cache control settings, since
  // it defaults to something, and we hit obs search repeatedly for stats. A
  // better approach might be to have a separate endpoints that delivers these
  // stats uncached, or disable cache-control when viewer_id is set or
  // something.
  ttl: -1
};

const HIDDEN_PARAMS = ["dateType", "createdDateType"];

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
    if ( newValue === "true" ) newValue = true;
    else if ( newValue === "false" ) newValue = false;
    // coerce integerish strings to numbers
    if (
      typeof( newValue ) === "string"
      && newValue.match( /^\d+$/ )
    ) {
      newValue = parseInt( newValue, 10 );
    }
    // coerce arrayish strings to arrays
    if ( k === "month" && !_.isArray( newValue ) ) {
      newValue = newValue.toString( ).split( "," ).map( m => parseInt( m, 10 ) );
    } else if ( typeof( newValue ) === "string" && newValue.split( "," ).length > 1 ) {
      newValue = newValue.split( "," );
    }
    if ( k === "iconic_taxa" && typeof( newValue ) === "string" ) {
      newValue = [newValue];
    }
    newParams[k] = newValue;
  } );

  if ( newParams.dateType === "exact" ) {
    newParams.dateType = "exact";
    delete newParams.d1;
    delete newParams.d2;
    delete newParams.month;
  } else if ( newParams.d1 || newParams.dateType === "range" ) {
    newParams.dateType = "range";
    delete newParams.on;
    delete newParams.month;
  } else if ( newParams.dateType === "month" ) {
    newParams.dateType = "month";
    delete newParams.d1;
    delete newParams.d2;
    delete newParams.on;
  } else {
    delete newParams.dateType;
    delete newParams.on;
    delete newParams.d1;
    delete newParams.d2;
    delete newParams.month;
  }

  if ( newParams.createdDateType === "exact" ) {
    newParams.createdDateType = "exact";
    delete newParams.created_d1;
    delete newParams.created_d2;
    delete newParams.created_month;
  } else if ( newParams.createdDateType === "range" ) {
    newParams.createdDateType = "range";
    delete newParams.created_on;
    delete newParams.created_month;
  } else if ( newParams.createdDateType === "month" ) {
    newParams.createdDateType = "month";
    delete newParams.created_d1;
    delete newParams.created_d2;
    delete newParams.created_on;
  } else {
    delete newParams.createdDateType;
    delete newParams.created_on;
    delete newParams.created_d1;
    delete newParams.created_d2;
    delete newParams.created_month;
  }
  return newParams;
};

const setUrl = ( newState ) => {
  const urlState = {};
  _.forEach( newState, ( v, k ) => {
    // don't put defaults in the URL
    if ( DEFAULT_PARAMS[k] !== undefined && DEFAULT_PARAMS[k] === v ) {
      return;
    }
    if ( HIDDEN_PARAMS.indexOf( k ) >= 0 ) {
      return;
    }
    if ( _.isArray( v ) && v.length === 0 ) {
      return;
    }
    let newVal = v;
    if ( _.isArray( v ) ) {
      newVal = v.join( "," );
    }
    urlState[k] = newVal;
  } );
  const title = `Identify: ${$.param( urlState )}`;
  const newUrl = [
    window.location.origin,
    window.location.pathname,
    _.isEmpty( urlState ) ? "" : "?",
    _.isEmpty( urlState ) ? "" : $.param( urlState )
  ].join( "" );
  history.pushState( urlState, title, newUrl );
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
  setUrl( newState );
  return newState;
};

export default searchParamsReducer;
export { normalizeParams, DEFAULT_PARAMS };
