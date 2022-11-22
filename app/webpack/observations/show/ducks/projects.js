import inatjs from "inaturalistjs";
import { callAPI, hasObsAndLoggedIn } from "./observation";

// eslint-disable-next-line import/prefer-default-export
export function joinProject( project ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    if ( !project || !project.id ) { return; }
    dispatch( callAPI( inatjs.projects.join, { id: project.id } ) );
  };
}
