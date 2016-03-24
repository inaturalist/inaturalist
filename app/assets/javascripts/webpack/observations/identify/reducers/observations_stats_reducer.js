import { UPDATE_OBSERVATIONS_STATS } from "../actions";

const observationsStatsReducer = ( state = {}, action ) => {
  if ( action.type === UPDATE_OBSERVATIONS_STATS ) {
    return Object.assign( {}, state, action.stats );
  }
  return state;
};

export default observationsStatsReducer;
