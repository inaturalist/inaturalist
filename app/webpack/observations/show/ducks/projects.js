import inatjs from "inaturalistjs";
import { fetchObservation } from "./observation";
import { handleAPIError } from "./confirm_modal";

export function joinProject( project ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser || !state.observation ||
         !project || !project.id ) {
      return;
    }
    inatjs.projects.join( { id: project.id } ).then( ( ) => {
      dispatch( fetchObservation( state.observation.id ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( state.observation.id ) );
    } );
  };
}
