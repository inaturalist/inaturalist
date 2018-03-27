import _ from "lodash";
import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware, combineReducers } from "redux";
import AppContainer from "./containers/app_container";
import configReducer, { setConfig } from "../../shared/ducks/config";
import projectReducer, { setProject, fetchOverviewData, setSelectedTab } from "./ducks/project";
import photoModalReducer from "../../taxa/shared/ducks/photo_modal";
/* global PROJECT_DATA */
/* global CURRENT_TAB */
/* global CURRENT_SUBTAB */

const rootReducer = combineReducers( {
  config: configReducer,
  project: projectReducer,
  photoModal: photoModalReducer
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
  // we use this for requesting localized taoxn names
  store.dispatch( setConfig( {
    preferredPlace: PREFERRED_PLACE
  } ) );
}

store.dispatch( setProject( PROJECT_DATA ) );
store.dispatch( fetchOverviewData( ) );
store.dispatch( setSelectedTab( CURRENT_TAB, { subtab: CURRENT_SUBTAB, replaceState: true } ) );

render(
  <Provider store={store}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);

window.onpopstate = e => {
  store.dispatch( setSelectedTab( e.state.selectedTab, { skipState: true } ) );
};

