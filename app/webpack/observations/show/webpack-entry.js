import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware, combineReducers } from "redux";
import AppContainer from "./containers/app_container";
import observationReducer, { fetchObservation, showNewObservation } from "./ducks/observation";
import observationPlacesReducer from "./ducks/observation_places";
import identificationsReducer from "./ducks/identifications";
import controlledTermsReducer from "./ducks/controlled_terms";
import otherObservationsReducer from "./ducks/other_observations";
import qualityMetricsReducer from "./ducks/quality_metrics";
import subscriptionsReducer from "./ducks/subscriptions";
import flaggingModalReducer from "./ducks/flagging_modal";
import confirmModalReducer from "./ducks/confirm_modal";
import communityIDModalReducer from "./ducks/community_id_modal";
import configReducer, { setConfig } from "../../shared/ducks/config";

const rootReducer = combineReducers( {
  config: configReducer,
  observation: observationReducer,
  identifications: identificationsReducer,
  observationPlaces: observationPlacesReducer,
  controlledTerms: controlledTermsReducer,
  qualityMetrics: qualityMetricsReducer,
  otherObservations: otherObservationsReducer,
  subscriptions: subscriptionsReducer,
  flaggingModal: flaggingModalReducer,
  confirmModal: confirmModalReducer,
  communityIDModal: communityIDModalReducer
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

if ( CURRENT_USER !== undefined && CURRENT_USER !== null ) {
  store.dispatch( setConfig( {
    currentUser: CURRENT_USER
  } ) );
}

if ( PREFERRED_PLACE !== undefined && PREFERRED_PLACE !== null ) {
  // we use this for requesting localized taoxn names
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

window.onpopstate = e => {
  if ( e.state && e.state.observation ) {
    store.dispatch( showNewObservation( e.state.observation, { skipSetState: true } ) );
  }
};

$( ( ) => {
  setTimeout( ( ) => {
    $( "p#flash" ).fadeOut( 1000 );
  }, 3000 );
} );
