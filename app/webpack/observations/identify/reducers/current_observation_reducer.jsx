import { SHOW_CURRENT_OBSERVATION, HIDE_CURRENT_OBSERVATION } from "../actions";

const currentObservationReducer = ( state = { visible: false }, action ) => {
  if ( action.type === SHOW_CURRENT_OBSERVATION ) {
    return {
      visible: true,
      observation: action.observation
    };
  } else if ( action.type === HIDE_CURRENT_OBSERVATION ) {
    return {
      visible: false,
      observation: state.observation
    };
  }
  return state;
};

export default currentObservationReducer;
