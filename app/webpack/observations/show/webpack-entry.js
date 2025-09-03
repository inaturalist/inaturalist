import _ from "lodash";
import "core-js/stable";
import "regenerator-runtime/runtime";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import moment from "moment";
import inatjs from "inaturalistjs";
import AppContainer from "./containers/app_container";
import commentIDPanelReducer from "./ducks/comment_id_panel";
import communityIDModalReducer from "./ducks/community_id_modal";
import { setConfig, setCurrentUser } from "../../shared/ducks/config";
import confirmModalReducer from "../../shared/ducks/confirm_modal";
import controlledTermsReducer from "./ducks/controlled_terms";
import flaggingModalReducer from "./ducks/flagging_modal";
import identificationsReducer from "./ducks/identifications";
import licensingModalReducer from "./ducks/licensing_modal";
import mediaViewerReducer from "./ducks/media_viewer";
import observationPlacesReducer from "./ducks/observation_places";
import observationReducer, { fetchObservation, showNewObservation } from "./ducks/observation";
import otherObservationsReducer from "./ducks/other_observations";
import projectFieldsModalReducer from "./ducks/project_fields_modal";
import qualityMetricsReducer from "./ducks/quality_metrics";
import subscriptionsReducer from "./ducks/subscriptions";
import relationshipsReducer from "./ducks/relationships";
import disagreementAlertReducer from "../shared/ducks/disagreement_alert";
import setupKeyboardShortcuts from "./keyboard_shortcuts";
import currentObservationReducer from "../identify/reducers/current_observation_reducer";
import suggestionsReducer from "../identify/ducks/suggestions";
import moderatorActionsReducer from "../../shared/ducks/moderator_actions";
import textEditorReducer from "../shared/ducks/text_editors";
import brightnessesReducer from "../identify/ducks/brightnesses";
import sharedStore from "../../shared/shared_store";

// Use custom relative times for moment
const shortRelativeTime = I18n.t( "momentjs" ) ? I18n.t( "momentjs" ).shortRelativeTime : null;
const relativeTime = {
  ...I18n.t( "momentjs", { locale: "en" } ).shortRelativeTime,
  ...shortRelativeTime
};
moment.locale( I18n.locale );
moment.updateLocale( moment.locale( ), { relativeTime } );

sharedStore.injectReducers( {
  commentIDPanel: commentIDPanelReducer,
  communityIDModal: communityIDModalReducer,
  confirmModal: confirmModalReducer,
  controlledTerms: controlledTermsReducer,
  flaggingModal: flaggingModalReducer,
  identifications: identificationsReducer,
  licensingModal: licensingModalReducer,
  mediaViewer: mediaViewerReducer,
  observation: observationReducer,
  observationPlaces: observationPlacesReducer,
  otherObservations: otherObservationsReducer,
  projectFieldsModal: projectFieldsModalReducer,
  qualityMetrics: qualityMetricsReducer,
  textEditor: textEditorReducer,
  subscriptions: subscriptionsReducer,
  relationships: relationshipsReducer,
  disagreementAlert: disagreementAlertReducer,
  moderatorActions: moderatorActionsReducer,

  // stuff from identify, where the "current observation" is the obs in a modal
  currentObservation: currentObservationReducer,
  suggestions: suggestionsReducer,
  brightnesses: brightnessesReducer
} );

if ( !_.isEmpty( CURRENT_USER ) ) {
  sharedStore.dispatch( setCurrentUser( CURRENT_USER ) );
}

if ( !_.isEmpty( PREFERRED_PLACE ) ) {
  // we use this for requesting localized taxon names
  sharedStore.dispatch( setConfig( {
    preferredPlace: PREFERRED_PLACE
  } ) );
}

const urlParams = new URLSearchParams( window.location.search );

const element = document.querySelector( "meta[name=\"config:inaturalist_api_url\"]" );
const defaultApiUrl = element && element.getAttribute( "content" );
if ( defaultApiUrl ) {
  sharedStore.dispatch( setConfig( {
    testingApiV2: true
  } ) );
  inatjs.setConfig( {
    apiURL: defaultApiUrl.replace( "/v1", "/v2" ),
    writeApiURL: defaultApiUrl.replace( "/v1", "/v2" )
  } );
}

const testFeature = urlParams.get( "test_feature" );
if ( testFeature ) {
  sharedStore.dispatch( setConfig( {
    testFeature
  } ) );
}

/* global INITIAL_OBSERVATION_UUID */
sharedStore.dispatch( fetchObservation( INITIAL_OBSERVATION_UUID, {
  fetchAll: true,
  replaceState: true,
  initialPhotoID: urlParams.get( "photo_id" ),
  callback: ( ) => {
    render(
      <Provider store={sharedStore}>
        <AppContainer />
      </Provider>,
      document.getElementById( "app" )
    );
  }
} ) );

setupKeyboardShortcuts( sharedStore.dispatch );

window.onpopstate = e => {
  if ( e.state && e.state.observation ) {
    sharedStore.dispatch( showNewObservation( e.state.observation, { skipSetState: true } ) );
  }
};
