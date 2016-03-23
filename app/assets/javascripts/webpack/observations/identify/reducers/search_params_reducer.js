import { UPDATE_SEARCH_PARAMS } from "../actions";

const searchParamsReducer = ( state = {}, action ) => {
  if ( action.type === UPDATE_SEARCH_PARAMS ) {
    return Object.assign( state, action.params );
  }
  return state;
};

export default searchParamsReducer;
