import {
  SHOW_FINISHED_MODAL,
  HIDE_FINISHED_MODAL
} from "../actions";

const finishedModalReducer = ( state = { visible: false }, action ) => {
  if ( action.type === SHOW_FINISHED_MODAL ) {
    return { visible: true };
  } else if ( action.type === HIDE_FINISHED_MODAL ) {
    return { visible: false };
  }
  return state;
};

export default finishedModalReducer;
