import inatjs from "inaturalistjs";
import { fetchObservation } from "./observation";
import { handleAPIError } from "./confirm_modal";

export function createFlag( className, id, flag, body ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const params = { flag: {
      flaggable_type: className,
      flaggable_id: id,
      flag
    }, flag_explanation: body };
    inatjs.flags.create( params ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( observationID ) );
    } );
  };
}

export function deleteFlag( id ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    inatjs.flags.delete( { id } ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( observationID ) );
    } );
  };
}
