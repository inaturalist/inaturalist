import iNaturalistJS from "inaturalistjs";

const SHOW_CURRENT_OBSERVATION = "show_current_observation";
const HIDE_CURRENT_OBSERVATION = "hide_current_observation";
const FETCH_CURRENT_OBSERVATION = "fetch_current_observation";
const RECEIVE_CURRENT_OBSERVATION = "receive_current_observation";

function showCurrentObservation( observation ) {
  return {
    type: SHOW_CURRENT_OBSERVATION,
    observation
  };
}

function hideCurrentObservation( ) {
  return { type: HIDE_CURRENT_OBSERVATION };
}

function receiveCurrentObservation( observation ) {
  return {
    type: RECEIVE_CURRENT_OBSERVATION,
    observation
  };
}

function fetchCurrentObservation( observation ) {
  return function ( dispatch ) {
    return iNaturalistJS.observations.fetch( [observation.id] )
      .then( response => {
        dispatch( receiveCurrentObservation( response.results[0] ) );
      } );
  };
}

export {
  SHOW_CURRENT_OBSERVATION,
  HIDE_CURRENT_OBSERVATION,
  FETCH_CURRENT_OBSERVATION,
  RECEIVE_CURRENT_OBSERVATION,
  showCurrentObservation,
  hideCurrentObservation,
  fetchCurrentObservation,
  receiveCurrentObservation
};
