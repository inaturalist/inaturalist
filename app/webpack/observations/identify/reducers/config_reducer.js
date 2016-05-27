import { CONFIG } from "../actions";

const configReducer = ( state = {}, action ) => {
  switch ( action.type ) {
    case CONFIG:
      return Object.assign( {}, state, action.config );
    default:
      return state;
  }
};

export default configReducer;
