/**
  Here's roughly what the state should look like:
  {
    config: {
      // configs, just key / values
    }
    observations: [
      // observations API responses
    ],
    currentObservation: {
      visible: false,
      observation: {
        // observation
      }
    }
  }
**/
import { combineReducers } from "redux";
import observations from "./observations_reducer";
import currentObservation from "./current_observation_reducer";
import config from "./config_reducer.js";

const rootReducer = combineReducers( {
  config,
  observations,
  currentObservation
} );

export default rootReducer;
