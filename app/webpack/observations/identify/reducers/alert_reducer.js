import {
  SHOW_ALERT,
  HIDE_ALERT
} from "../actions";

const alertReducer = ( state = { visible: false }, action ) => {
  if ( action.type === SHOW_ALERT ) {
    return Object.assign( { visible: true, content: action.content }, action.options );
  } else if ( action.type === HIDE_ALERT ) {
    return Object.assign( {}, state, { visible: false } );
  }
  return state;
};

export default alertReducer;
