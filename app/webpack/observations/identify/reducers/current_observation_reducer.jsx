import {
  SHOW_CURRENT_OBSERVATION,
  HIDE_CURRENT_OBSERVATION,
  RECEIVE_CURRENT_OBSERVATION,
  ADD_COMMENT,
  ADD_IDENTIFICATION
} from "../actions";

const currentObservationReducer = ( state = {}, action ) => {
  switch ( action.type ) {
    case SHOW_CURRENT_OBSERVATION:
      return Object.assign( {}, state, {
        visible: true,
        observation: action.observation,
        commentFormVisible: false,
        identificationFormVisible: false
      } );
    case HIDE_CURRENT_OBSERVATION:
      return Object.assign( {}, state, {
        visible: false,
        observation: state.observation
      } );
    case RECEIVE_CURRENT_OBSERVATION:
      return Object.assign( {}, state, {
        visible: true,
        observation: action.observation
      } );
    case ADD_COMMENT:
      return Object.assign( {}, state, {
        commentFormVisible: true,
        identificationFormVisible: false
      } );
    case ADD_IDENTIFICATION:
      return Object.assign( {}, state, {
        identificationFormVisible: true,
        commentFormVisible: false
      } );
    default:
      return state;
  }
};

export default currentObservationReducer;
