import inatjs from "inaturalistjs";
import { callAPI, hasObsAndLoggedIn } from "./observation";

export function createFlag( className, id, flag, body ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const params = {
      flag: {
        flaggable_type: className,
        flaggable_id: id,
        flag
      },
      flag_explanation: body
    };
    dispatch( callAPI( inatjs.flags.create, params ) );
  };
}

export function deleteFlag( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    dispatch( callAPI( inatjs.flags.delete, { id } ) );
  };
}
