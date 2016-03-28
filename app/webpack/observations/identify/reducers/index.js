/**
  Here's roughly what the state should look like:
  {
    config: {
      // configs, just key / values
    },
    observations: [
      // observations API responses
    ],
    observationsStats: {
      researchGrade: 123,
      needsId: 123,
      casual: 123
    }
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
import observationsStats from "./observations_stats_reducer";
import currentObservation from "./current_observation_reducer";
import config from "./config_reducer";
import searchParams from "./search_params_reducer";

const rootReducer = combineReducers( {
  config,
  observations,
  observationsStats,
  currentObservation,
  searchParams
} );

export default rootReducer;
