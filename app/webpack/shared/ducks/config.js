// ACTIONS
const CONFIG = "CONFIG";

// REDUCER
export default function reducer( state = {}, action ) {
  switch ( action.type ) {
    case CONFIG:
      return Object.assign( {}, state, action.config );
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
