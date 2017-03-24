import inatjs from "inaturalistjs";
import { fetchObservation } from "./observation";
import { handleAPIError } from "./confirm_modal";

export function updateCuratorAccess( projectObservation, value ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser || !state.observation ||
         !projectObservation || !projectObservation.uuid ) {
      return;
    }
    const params = {
      id: projectObservation.uuid,
      project_observation: {
        prefers_curator_coordinate_access: value
      }
    };
    inatjs.project_observations.update( params ).then( ( ) => {
      dispatch( fetchObservation( state.observation.id ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( state.observation.id ) );
    } );
  };
}
