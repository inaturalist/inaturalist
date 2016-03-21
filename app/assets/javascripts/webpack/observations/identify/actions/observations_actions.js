import iNaturalistJS from "inaturalistjs";

const RECEIVE_OBSERVATIONS = "receive_observations";

function receiveObservations( observations ) {
  return {
    type: RECEIVE_OBSERVATIONS,
    observations
  };
}

function fetchObservations( params = {} ) {
  return function ( dispatch, getState ) {
    if( params.verifiable === undefined ) {
      params.verifiable = true;
    }
    return iNaturalistJS.observations.search( params )
      .then( response => {
        console.log( "[DEBUG] response.results: ", response.results );
        dispatch( receiveObservations( response.results ) );
      } );
  };
}

export {
  RECEIVE_OBSERVATIONS,
  receiveObservations,
  fetchObservations
};
