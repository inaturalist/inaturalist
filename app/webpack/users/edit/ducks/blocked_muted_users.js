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
      const errors = json?.error?.original?.errors?.base
        || json?.errors?.map( error => {
          if ( typeof ( error ) === "string" ) return error;
          if ( error?.message?.match( /\{/ ) ) {
            try {
              const crazyErrors = JSON.parse( error.message );
              return crazyErrors.errors.base.join( "; " ).replace( /\s+/g, " " );
            } catch ( parseError ) {
              console.error( "Failed to deal with weird error: ", parseError );
              return I18n.t( "doh_something_went_wrong" );
            }
          }
          return error.message;
        } )
        || [];
      if ( errors.length > 0 ) {
        alert( errors.join( "; " ) );
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
