import _ from "lodash";
import "@babel/polyfill";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import {
  createStore, compose, applyMiddleware, combineReducers
} from "redux";
import AppContainer from "./containers/app_container";
import lifelistReducer, { fetchUser, updateWithHistoryState } from "./reducers/lifelist";
import exportModalReducer from "./reducers/export_modal";
import configReducer, { setConfig } from "../../shared/ducks/config";
import inatAPIReducer from "../../shared/ducks/inat_api_duck";

const rootReducer = combineReducers( {
  config: configReducer,
  lifelist: lifelistReducer,
  inatAPI: inatAPIReducer,
  exportModal: exportModalReducer
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

if ( !_.isEmpty( SITE ) ) {
  store.dispatch( setConfig( {
    site: SITE
  } ) );
}

if ( !_.isEmpty( PREFERRED_PLACE ) ) {
  // we use this for requesting localized taoxn names
  store.dispatch( setConfig( {
    preferredPlace: PREFERRED_PLACE
  } ) );
}

/* global LIFELIST_USER */
store.dispatch( fetchUser( LIFELIST_USER, {
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
  store.dispatch( updateWithHistoryState( e.state ) );
};
