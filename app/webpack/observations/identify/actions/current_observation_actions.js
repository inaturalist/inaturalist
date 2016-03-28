const SHOW_CURRENT_OBSERVATION = "show_current_observation";
const HIDE_CURRENT_OBSERVATION = "hide_current_observation";

function showCurrentObservation( observation ) {
  return {
    type: SHOW_CURRENT_OBSERVATION,
    observation
  };
}

function hideCurrentObservation( ) {
  return { type: HIDE_CURRENT_OBSERVATION };
}

export {
  SHOW_CURRENT_OBSERVATION,
  HIDE_CURRENT_OBSERVATION,
  showCurrentObservation,
  hideCurrentObservation
};
