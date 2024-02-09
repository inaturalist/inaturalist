/*
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
*/
import { combineReducers } from "redux";
import observations from "./observations_reducer";
import observationsStats from "./observations_stats_reducer";
import currentObservation from "./current_observation_reducer";
import config from "../../../shared/ducks/config";
import searchParams from "./search_params_reducer";
import finishedModal from "./finished_modal_reducer";
import alertModal from "../../../shared/ducks/alert_modal";
import textEditor from "../../shared/ducks/text_editors";
import suggestions from "../ducks/suggestions";
import controlledTerms from "../../show/ducks/controlled_terms";
import qualityMetrics from "../../show/ducks/quality_metrics";
import flaggingModal from "../../show/ducks/flagging_modal";
import subscriptions from "../../show/ducks/subscriptions";
import disagreementAlert from "../../shared/ducks/disagreement_alert";
import moderatorActions from "../../../shared/ducks/moderator_actions";
import brightnesses from "../ducks/brightnesses";
import confirmModal from "../../show/ducks/confirm_modal";
import projectFieldsModal from "../../show/ducks/project_fields_modal";

const rootReducer = combineReducers( {
  config,
  observations,
  observationsStats,
  currentObservation,
  searchParams,
  finishedModal,
  alertModal,
  textEditor,
  suggestions,
  controlledTerms,
  qualityMetrics,
  flaggingModal,
  subscriptions,
  disagreementAlert,
  moderatorActions,
  brightnesses,
  confirmModal,
  projectFieldsModal
} );

export default rootReducer;
