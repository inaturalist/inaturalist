import fetch from "isomorphic-fetch";

const RECEIVE_OBSERVATIONS = "receive_observations";

function receiveObservations( observations ) {
  return {
    type: RECEIVE_OBSERVATIONS,
    observations
  };
}

function fetchObservations( params = {} ) {
  return function ( dispatch, getState ) {
    const nodeApiHost = getState().config.nodeApiHost;
    // might also consider https://nodejs.org/api/querystring.html for this
    let urlParams = $.param( params );
    urlParams += "&verifiable=true";
    return fetch( `//${nodeApiHost}/v1/observations?${urlParams}` )
      .then( response => {
        console.log( "[DEBUG] response: ", response );
        return response.json( );
      } )
      .then( json => {
        console.log( "[DEBUG] json.results: ", json.results );
        dispatch( receiveObservations( json.results ) );
      } );
  };
}

export {
  RECEIVE_OBSERVATIONS,
  receiveObservations,
  fetchObservations
};
