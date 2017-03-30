import inatjs from "inaturalistjs";
import { getActionTime, afterAPICall, hasObsAndLoggedIn } from "./observation";

export function createFlag( className, id, flag, body ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const params = { flag: {
      flaggable_type: className,
      flaggable_id: id,
      flag
    }, flag_explanation: body };
    const actionTime = getActionTime( );
    inatjs.flags.create( params ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, { actionTime } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, { actionTime, error: e } ) );
    } );
  };
}

export function deleteFlag( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const actionTime = getActionTime( );
    inatjs.flags.delete( { id } ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, { actionTime } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, { actionTime, error: e } ) );
    } );
  };
}
