import inatjs from "inaturalistjs";

const SET_SUBSCRIPTIONS = "obs-show/subscriptions/SET_SUBSCRIPTIONS";
const RESET_SUBSCRIPTIONS = "obs-show/subscriptions/RESET_SUBSCRIPTIONS";

export default function reducer( state = {
  subscriptions: [],
  loaded: false
}, action ) {
  switch ( action.type ) {
    case SET_SUBSCRIPTIONS:
      state.subscriptions = action.subscriptions;
      state.loaded = true;
      break;
    case RESET_SUBSCRIPTIONS:
      state.subscriptions = [];
      state.loaded = false;
      break;
    default:
      // Do nothing
  }
  return state;
}

export function setSubscriptions( subscriptions ) {
  return {
    type: SET_SUBSCRIPTIONS,
    subscriptions
  };
}

export function resetSubscriptions( ) {
  return { type: RESET_SUBSCRIPTIONS };
}

export function fetchSubscriptions( options = {} ) {
  return ( dispatch, getState ) => {
    const observation = options.observation || getState( ).observation;
    if ( !observation ) { return null; }
    const params = { id: observation.id };
    return inatjs.observations.subscriptions( params ).then( response => {
      dispatch( setSubscriptions( response.results ) );
    } ).catch( e => { } );
  };
}
