import {
  SET_BRIGHTNESSES
} from "../actions";

const brightnessReducer = ( state = { brightnesses: { } }, action ) => {
  if ( action.type === SET_BRIGHTNESSES ) {
    return Object.assign( { brightnesses: action.brightnesses } );
  }
  return state;
};

export default brightnessReducer;
