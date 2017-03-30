import inatjs from "inaturalistjs";
import { callAPI, hasObsAndLoggedIn } from "./observation";

export function updateCuratorAccess( projectObservation, value ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    if ( !projectObservation || !projectObservation.uuid ) { return; }
    const params = {
      id: projectObservation.uuid,
      project_observation: {
        prefers_curator_coordinate_access: value
      }
    };
    dispatch( callAPI( inatjs.project_observations.update, params ) );
  };
}
