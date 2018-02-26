import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware, combineReducers } from "redux";
import utf8 from "utf8";
import configReducer from "../../shared/ducks/config";
import compareReducer, { fetchDataForTab } from "./ducks/compare";
import App from "./components/app";

const rootReducer = combineReducers( {
  compare: compareReducer,
  config: configReducer
} );

const urlParams = $.deparam( window.location.search.replace( /^\?/, "" ) );
let initialState;
if ( urlParams && urlParams.s ) {
  const encoded = atob( urlParams.s );
  const json = utf8.decode( encoded );
  initialState = JSON.parse( json );
}

const store = createStore(
  rootReducer,
  {
    compare: initialState
  },
  compose(
    applyMiddleware(
      thunkMiddleware
    ),
    // enable Redux DevTools if available
    window.devToolsExtension ? window.devToolsExtension() : applyMiddleware()
  )
);

store.dispatch( fetchDataForTab( ) );

render(
  <Provider store={store}>
    <App />
  </Provider>,
  document.getElementById( "app" )
);
