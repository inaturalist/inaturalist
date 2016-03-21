import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import { createStore, compose, applyMiddleware } from "redux";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";

import rootReducer from "./reducers/";
import { fetchObservations, setConfig } from "./actions/";
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
  nodeApiHost: $( "[name='config:node_api_host']" ).attr( "content" ),
  csrfParam: $( "[name='csrf-param']" ).attr( "content" ),
  csrfToken: $( "[name='csrf-token']" ).attr( "content" ),
  apiToken: $( "[name='inaturalist-api-token']" ).attr( "content" )
} ) );

// retrieve initial set of observations
store.dispatch( fetchObservations() );

render(
  <Provider store={store}>
    <App />
  </Provider>,
  document.getElementById( "app" )
);
