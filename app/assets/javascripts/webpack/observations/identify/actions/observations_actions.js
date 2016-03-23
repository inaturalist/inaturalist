import iNaturalistJS from "inaturalistjs";

const RECEIVE_OBSERVATIONS = "receive_observations";

function receiveObservations( observations ) {
  return {
    type: RECEIVE_OBSERVATIONS,
    observations
  };
}

function fetchObservations( ) {
  return function ( dispatch, getState ) {
    const s = getState();
    const apiParams = Object.assign( {
      verifiable: true,
      reviewed: false,
      viewer_id: s.config.currentUser ? s.config.currentUser.id : null
    }, s.searchParams );
    return iNaturalistJS.observations.search( apiParams )
      .then( response => {
        dispatch( receiveObservations( response.results ) );
      } );
  };
}

export {
  RECEIVE_OBSERVATIONS,
  receiveObservations,
  fetchObservations
};
