import {
  SHOW_CURRENT_OBSERVATION,
  HIDE_CURRENT_OBSERVATION,
  RECEIVE_CURRENT_OBSERVATION
} from "../actions";

const currentObservationReducer = ( state = { visible: false }, action ) => {
  switch ( action.type ) {
    case SHOW_CURRENT_OBSERVATION:
      return {
        visible: true,
        observation: action.observation
      };
    case HIDE_CURRENT_OBSERVATION:
      return {
        visible: false,
        observation: state.observation
      };
    case RECEIVE_CURRENT_OBSERVATION:
      return {
        visible: true,
        observation: action.observation
      };
    default:
      return state;
  }
};

export default currentObservationReducer;
