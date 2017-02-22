import inatjs from "inaturalistjs";

const SET_SUBSCRIPTIONS = "obs-show/subscriptions/SET_SUBSCRIPTIONS";

export default function reducer( state = [], action ) {
  switch ( action.type ) {
    case SET_SUBSCRIPTIONS:
      return action.subscriptions;
    default:
  }
  return state;
}

export function setSubscriptions( subscriptions ) {
  return {
    type: SET_SUBSCRIPTIONS,
    subscriptions
  };
}

export function fetchSubscriptions( ) {
  return ( dispatch, getState ) => {
    const observation = getState( ).observation;
    if ( !observation ) { return null; }
    const params = { id: observation.id };
    return inatjs.observations.subscriptions( params ).then( response => {
      dispatch( setSubscriptions( response.results ) );
    } );
  };
}
