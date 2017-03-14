import inatjs from "inaturalistjs";
import { setConfig } from "../../../shared/ducks/config";

const UPDATE_SESSION = "obs-show/users/UPDATE_SESSION";

export default function reducer( state = [], action ) {
  switch ( action.type ) {
    case UPDATE_SESSION:
      return action.subscriptions;
    default:
  }
  return state;
}

export function setSubscriptions( subscriptions ) {
  return {
    type: UPDATE_SESSION,
    subscriptions
  };
}

export function updateSession( params ) {
  return ( dispatch, getState ) => {
    const config = getState( ).config;
    if ( !config || !config.currentUser ) { return null; }
    return inatjs.users.update_session( params ).then( ( ) => {
      const updatedUser = Object.assign( { }, config.currentUser, params );
      dispatch( setConfig( { currentUser: updatedUser } ) );
    } );
  };
}
