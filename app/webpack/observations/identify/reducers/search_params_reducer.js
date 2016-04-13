import { UPDATE_SEARCH_PARAMS } from "../actions";

const searchParamsReducer = ( state = {
  reviewed: false,
  quality_grade: "needs_id",
  verifiable: true
}, action ) => {
  if ( action.type === UPDATE_SEARCH_PARAMS ) {
    return Object.assign( {}, state, action.params );
  }
  return state;
};

export default searchParamsReducer;
