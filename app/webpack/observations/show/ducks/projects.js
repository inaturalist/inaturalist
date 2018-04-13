import inatjs from "inaturalistjs";
import { callAPI, hasObsAndLoggedIn } from "./observation";

export function joinProject( project ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    if ( !project || !project.id ) { return; }
    dispatch( callAPI( inatjs.projects.join, { id: project.id } ) );
  };
}
