import { UPDATE_OBSERVATIONS_STATS } from "../actions";

const observationsStatsReducer = ( state = {
  research: 0,
  needsId: 0,
  casual: 0,
  reviewed: 0,
  total: 0,
  status: null
}, action ) => {
  if ( action.type === UPDATE_OBSERVATIONS_STATS ) {
    return Object.assign( { }, state, action.stats );
  }
  return state;
};

export default observationsStatsReducer;
