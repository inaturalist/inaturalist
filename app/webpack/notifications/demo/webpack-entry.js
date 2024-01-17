import "core-js/stable";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import {
  createStore, compose, applyMiddleware, combineReducers
} from "redux";
import AppContainer from "./container";
import DemoReducer, { initialize } from "./reducer";

const rootReducer = combineReducers( {
  apiResponse: DemoReducer
} );

const store = createStore(
  rootReducer,
  compose(
    applyMiddleware(
      thunkMiddleware
    ),
    // enable Redux DevTools if available
    window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
  )
);

/* global NOTIFICATIONS */
store.dispatch( initialize( NOTIFICATIONS, ( ) => {
  render(
    <Provider store={store}>
      <AppContainer />
    </Provider>,
    document.getElementById( "app" )
  );
} ) );
