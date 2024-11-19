import inatjs from "inaturalistjs";
import { fetchUserSettings } from "./user_settings";

export function muteUser( id ) {
  const params = { id };
  return dispatch => inatjs.users.mute( params ).then( ( ) => {
    dispatch( fetchUserSettings( false, true ) );
  } ).catch( e => console.log( `Failed to mute user: ${e}` ) );
}

export function unmuteUser( id ) {
  const params = { id };
  return dispatch => inatjs.users.unmute( params ).then( ( ) => {
    dispatch( fetchUserSettings( false, true ) );
  } ).catch( e => console.log( `Failed to unmute user: ${e}` ) );
}

export function blockUser( id ) {
  const params = { id };
  return dispatch => inatjs.users.block( params ).then( ( ) => {
    dispatch( fetchUserSettings( false, true ) );
  } ).catch( e => {
    e.response.json( ).then( json => {
      const baseErrors = _.get( json, "error.original.errors.base", [] );
      if ( baseErrors.length > 0 ) {
        alert( baseErrors.join( "; " ) );
      }
    } );
    console.log( `Failed to block user: ${e}` );
  } );
}

export function unblockUser( id ) {
  const params = { id };
  return dispatch => inatjs.users.unblock( params ).then( ( ) => {
    dispatch( fetchUserSettings( false, true ) );
  } ).catch( e => console.log( `Failed to unblock user: ${e}` ) );
}
