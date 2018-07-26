import _ from "lodash";
import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware, combineReducers } from "redux";
import moment from "moment";
import AppContainer from "./containers/app_container";
import commentIDPanelReducer from "./ducks/comment_id_panel";
import communityIDModalReducer from "./ducks/community_id_modal";
import configReducer, { setConfig } from "../../shared/ducks/config";
import confirmModalReducer from "./ducks/confirm_modal";
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
import disagreementAlertReducer from "../shared/ducks/disagreement_alert";
import setupKeyboardShortcuts from "./keyboard_shortcuts";
import currentObservationReducer from "../identify/reducers/current_observation_reducer";
import suggestionsReducer from "../identify/ducks/suggestions";

// Use custom relative times for moment
const shortRelativeTime = I18n.t( "momentjs" ) ? I18n.t( "momentjs" ).shortRelativeTime : null;
const relativeTime = Object.assign(
  {},
  I18n.t( "momentjs", { locale: "en" } ).shortRelativeTime,
  shortRelativeTime
);
moment.locale( I18n.locale );
moment.updateLocale( moment.locale(), { relativeTime } );

const rootReducer = combineReducers( {
  commentIDPanel: commentIDPanelReducer,
  communityIDModal: communityIDModalReducer,
  config: configReducer,
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
  subscriptions: subscriptionsReducer,
  disagreementAlert: disagreementAlertReducer,

  // stuff from identify, where the "current observation" is the obs in a modal
  currentObservation: currentObservationReducer,
  suggestions: suggestionsReducer
} );

const store = createStore(
  rootReducer,
  compose(
    applyMiddleware(
      thunkMiddleware
    ),
    // enable Redux DevTools if available
    window.devToolsExtension ? window.devToolsExtension() : applyMiddleware()
  )
);

if ( !_.isEmpty( CURRENT_USER ) ) {
  store.dispatch( setConfig( {
    currentUser: CURRENT_USER
  } ) );
}

if ( !_.isEmpty( PREFERRED_PLACE ) ) {
  // we use this for requesting localized taxon names
  store.dispatch( setConfig( {
    preferredPlace: PREFERRED_PLACE
  } ) );
}

/* global INITIAL_OBSERVATION_ID */
store.dispatch( fetchObservation( INITIAL_OBSERVATION_ID, {
  fetchAll: true,
  replaceState: true,
  callback: ( ) => {
    render(
      <Provider store={store}>
        <AppContainer />
      </Provider>,
      document.getElementById( "app" )
    );
  }
} ) );

setupKeyboardShortcuts( store.dispatch );

window.onpopstate = e => {
  if ( e.state && e.state.observation ) {
    store.dispatch( showNewObservation( e.state.observation, { skipSetState: true } ) );
  }
};
