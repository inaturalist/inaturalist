import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware, combineReducers } from "redux";
import configReducer from "../../shared/ducks/config";
import compareReducer, { chooseTab } from "./ducks/compare";
import App from "./components/app";

const rootReducer = combineReducers( {
  compare: compareReducer,
  config: configReducer
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

store.dispatch( chooseTab( "species" ) );

render(
  <Provider store={store}>
    <App />
  </Provider>,
  document.getElementById( "app" )
);
