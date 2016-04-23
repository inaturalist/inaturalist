import _ from "lodash";
import { RECEIVE_OBSERVATIONS, UPDATE_OBSERVATION_IN_COLLECTION } from "../actions";

const observationsReducer = ( state = { results: [] }, action ) => {
  if ( action.type === RECEIVE_OBSERVATIONS ) {
    return Object.assign( {}, state, {
      totalResults: action.totalResults,
      page: action.page,
      totalPages: action.totalPages,
      results: action.results
    } );
  } else if ( action.type === UPDATE_OBSERVATION_IN_COLLECTION ) {
    const newState = Object.assign( {}, state, {
      results: _.cloneDeep( state.results ).map( ( obs ) => {
        if ( obs.id === action.observation.id ) {
          _.forOwn( action.changes, ( v, k ) => {
            obs[k] = v;
          } );
        }
        return obs;
      } )
    } );
    return newState;
  }
  return state;
};

export default observationsReducer;
