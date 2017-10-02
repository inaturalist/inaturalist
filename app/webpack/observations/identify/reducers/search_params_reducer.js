import {
  UPDATE_SEARCH_PARAMS,
  RECEIVE_OBSERVATIONS,
  UPDATE_SEARCH_PARAMS_WITHOUT_HISTORY,
  UPDATE_DEFAULT_PARAMS,
  REPLACE_SEARCH_PARAMS
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
  order: "desc"
};

const HIDDEN_PARAMS = ["dateType", "createdDateType", "force"];

// Coerce params into a consistent format for update the state
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
  if ( !newParams.dateType ) {
    if ( newParams.on ) {
      newParams.dateType = "exact";
    } else if ( newParams.d1 || newParams.d2 ) {
      newParams.dateType = "range";
    } else if ( newParams.month ) {
      newParams.dateType = "month";
    }
  }
  if ( !newParams.createdDateType ) {
    if ( newParams.created_on ) {
      newParams.createdDateType = "exact";
    } else if ( newParams.created_d1 || newParams.created_d2 ) {
      newParams.createdDateType = "range";
    } else if ( newParams.created_month ) {
      newParams.createdDateType = "month";
    }
  }
  return newParams;
};

// Filter search params for use in API requests
const paramsForSearch = ( params ) => {
  const newParams = {};
  _.forEach( params, ( v, k ) => {
    if ( HIDDEN_PARAMS.indexOf( k ) >= 0 ) {
      return;
    }
    if ( _.isArray( v ) && v.length === 0 ) {
      return;
    }
    newParams[k] = v;
  } );
  if ( params.dateType === "exact" ) {
    delete newParams.d1;
    delete newParams.d2;
    delete newParams.month;
  } else if ( params.dateType === "range" ) {
    delete newParams.on;
    delete newParams.month;
  } else if ( params.dateType === "month" ) {
    delete newParams.d1;
    delete newParams.d2;
    delete newParams.on;
  } else {
    delete newParams.on;
    delete newParams.d1;
    delete newParams.d2;
    delete newParams.month;
  }
  if ( params.createdDateType === "exact" ) {
    newParams.createdDateType = "exact";
    delete newParams.created_d1;
    delete newParams.created_d2;
    delete newParams.created_month;
  } else if ( params.createdDateType === "range" ) {
    newParams.createdDateType = "range";
    delete newParams.created_on;
    delete newParams.created_month;
  } else if ( params.createdDateType === "month" ) {
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

const setUrl = ( newParams, defaultParams ) => {
  // don't put defaults in the URL
  const urlState = {};
  _.forEach( paramsForSearch( newParams ), ( v, k ) => {
    if ( defaultParams[k] !== undefined && defaultParams[k] === v ) {
      return;
    }
    if ( _.isArray( v ) ) {
      urlState[k] = v.join( "," );
    } else {
      urlState[k] = v;
    }
  } );
  if ( !newParams.place_id && defaultParams.place_id ) {
    urlState.place_id = "any";
  }
  const title = `Identify: ${$.param( urlState )}`;
  const newUrl = [
    window.location.origin,
    window.location.pathname,
    _.isEmpty( urlState ) ? "" : "?",
    _.isEmpty( urlState ) ? "" : $.param( urlState )
  ].join( "" );
  history.pushState( urlState, title, newUrl );
};

const searchParamsReducer = ( state = {
  default: DEFAULT_PARAMS,
  params: DEFAULT_PARAMS
}, action ) => {
  let newState = state;
  switch ( action.type ) {
    case REPLACE_SEARCH_PARAMS:
      newState = Object.assign( {}, {
        default: Object.assign( {}, state.default ),
        params: Object.assign( {}, action.params )
      } );
      break;
    case UPDATE_SEARCH_PARAMS:
    case UPDATE_SEARCH_PARAMS_WITHOUT_HISTORY:
      newState = Object.assign( {}, {
        default: Object.assign( {}, state.default ),
        params: Object.assign( {}, state.params, action.params )
      } );
      break;
    case RECEIVE_OBSERVATIONS:
      newState = Object.assign( {}, {
        default: Object.assign( {}, state.default ),
        params: Object.assign( {}, state.params, {
          page: action.page,
          per_page: action.perPage
        } )
      } );
      break;
    case UPDATE_DEFAULT_PARAMS: {
      const newDefaults = Object.assign( {}, state.default, action.params );
      newState = Object.assign( {}, {
        default: newDefaults,
        params: Object.assign( {}, newDefaults, state.params )
      } );
      break;
    }
    default:
      return state;
  }
  newState.params = normalizeParams( newState.params );

  // if the states are equal there should be no reason to update the URL
  if ( _.isEqual( state.params, newState.params ) ) {
    return state;
  }
  // if we're popping or setting the initial state, the URL should already be updated
  if ( action.type === UPDATE_SEARCH_PARAMS_WITHOUT_HISTORY ) {
    return newState;
  }
  // if we're just setting the defaults, the URL does not need to update
  if (
    _.isEqual( newState.params, newState.default ) &&
    _.isEqual( state.params, newState.default )
  ) {
    return newState;
  }
  setUrl( newState.params, newState.default );
  return newState;
};

export default searchParamsReducer;
export { normalizeParams, paramsForSearch };
