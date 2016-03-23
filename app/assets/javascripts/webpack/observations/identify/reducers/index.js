/**
  Here's roughly what the state should look like:
  {
    config: {
      // configs, just key / values
    },
    observations: [
      // observations API responses
    ],
    currentObservation: {
      visible: false,
      observation: {
        // observation
      }
    },
    searchParams: {
      taxon_id: ...,
      place_id: ...,
      ...
    }
  }
**/
import { combineReducers } from "redux";
import observations from "./observations_reducer";
import currentObservation from "./current_observation_reducer";
import config from "./config_reducer";
import searchParams from "./search_params_reducer";

const rootReducer = combineReducers( {
  config,
  observations,
  currentObservation,
  searchParams
} );

export default rootReducer;
