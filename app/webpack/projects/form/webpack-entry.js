import _ from "lodash";
import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware, combineReducers } from "redux";
import AppContainer from "./containers/app_container";
import configReducer, { setConfig } from "../../shared/ducks/config";
import formReducer, { setProject } from "./form_reducer";
/* global PROJECT_DATA */
/* global CURRENT_PROJECT */

const rootReducer = combineReducers( {
  config: configReducer,
  form: formReducer
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

if ( !_.isEmpty( CURRENT_PROJECT ) ) {
  store.dispatch( setProject( CURRENT_PROJECT ) );
}

render(
  <Provider store={store}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
