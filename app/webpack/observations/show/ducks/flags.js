import inatjs from "inaturalistjs";
import { fetchObservation } from "./observation";

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
    } );
  };
}

export function deleteFlag( id ) {
  return ( dispatch, getState ) => (
    inatjs.flags.delete( { id } ).then( ( ) => {
      const observationID = getState( ).observation.id;
      dispatch( fetchObservation( observationID ) );
    } )
  );
}
