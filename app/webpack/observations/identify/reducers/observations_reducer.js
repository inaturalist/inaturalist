import _ from "lodash";
import { RECEIVE_OBSERVATIONS, UPDATE_OBSERVATION_IN_COLLECTION } from "../actions";

const observationsReducer = ( state = [], action ) => {
  if ( action.type === RECEIVE_OBSERVATIONS ) {
    return action.observations;
  } else if ( action.type === UPDATE_OBSERVATION_IN_COLLECTION ) {
    const newState = _.cloneDeep( state ).map( ( obs ) => {
      if ( obs.id === action.observation.id ) {
        _.forOwn( action.changes, ( v, k ) => {
          obs[k] = v;
        } );
      }
      return obs;
    } );
    return newState;
  }
  return state;
};

export default observationsReducer;
