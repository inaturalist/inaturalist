import { RECEIVE_OBSERVATIONS } from "../actions";

const observationsReducer = ( state = [], action ) => {
  if ( action.type === RECEIVE_OBSERVATIONS ) {
    return action.observations;
  }
  return state;
};

export default observationsReducer;
