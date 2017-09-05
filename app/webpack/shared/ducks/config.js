// ACTIONS
const CONFIG = "CONFIG";
const TOGGLE_CONFIG = "TOGGLE_CONFIG";

// REDUCER
export default function reducer( state = {}, action ) {
  switch ( action.type ) {
    case CONFIG:
      return Object.assign( {}, state, action.config );
    case TOGGLE_CONFIG:
      return Object.assign( {}, state, { [action.key]: !state[action.key] } );
    default:
      return state;
  }
}

// ACTION CREATORS
export function setConfig( config ) {
  return {
    type: CONFIG,
    config
  };
}

export function toggleConfig( key ) {
  return {
    type: TOGGLE_CONFIG,
    key
  };
}
