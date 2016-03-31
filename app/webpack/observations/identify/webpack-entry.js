// skip_uglifier
import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import { createStore, compose, applyMiddleware } from "redux";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";

import rootReducer from "./reducers/";
import {
  fetchObservations,
  fetchObservationsStats,
  setConfig
} from "./actions/";
import App from "./components/app";

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

store.dispatch( setConfig( {
  nodeApiHost: $( "[name='config:inaturalist_api_host']" ).attr( "content" )
} ) );

if ( CURRENT_USER !== undefined && CURRENT_USER !== null ) {
  store.dispatch( setConfig( {
    currentUser: CURRENT_USER
  } ) );
}

// retrieve initial set of observations
store.dispatch( fetchObservations() );
store.dispatch( fetchObservationsStats() );

render(
  <Provider store={store}>
    <App />
  </Provider>,
  document.getElementById( "app" )
);
