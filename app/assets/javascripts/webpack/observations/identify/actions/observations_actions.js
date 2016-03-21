import inatjs from "inaturalistjs";

const RECEIVE_OBSERVATIONS = "receive_observations";

function receiveObservations( observations ) {
  return {
    type: RECEIVE_OBSERVATIONS,
    observations
  };
}

function fetchObservations( params = {} ) {
  // return function ( dispatch, getState ) {
  return function ( dispatch ) {
    // this will have to come back, but for now the defaults will work
    // const nodeApiHost = getState().config.nodeApiHost
    inatjs.observations.search( params )
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
