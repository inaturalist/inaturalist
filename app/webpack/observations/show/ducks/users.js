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
    } ).catch( e => { } );
  };
}

export function leaveTestGroup( group ) {
  return ( dispatch, getState ) => {
    const config = getState( ).config;
    if ( !config || !config.currentUser ) { return null; }
    const csrfParam = $( "meta[name=csrf-param]" ).attr( "content" );
    const csrfToken = $( "meta[name=csrf-token]" ).attr( "content" );
    const body = new FormData( );
    body.append( csrfParam, csrfToken );
    const fetchOpts = {
      method: "put",
      credentials: "same-origin",
      body
    };

    const path = `/users/${config.currentUser.id}/leave_test?test=${group}`;
    return fetch( path, fetchOpts ).then( response => {
      if ( response.status >= 200 && response.status < 300 ) {
        location.reload( );
      } else {
        throw new Error( "there was a problem leaving the test group" );
      }
    } ).catch( e => {
      alert( e );
    } );
  };
}
