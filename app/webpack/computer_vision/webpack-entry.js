import "@babel/polyfill";
import thunkMiddleware from "redux-thunk";
import { createStore, compose, applyMiddleware, combineReducers } from "redux";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";

import computerVisionDemoReducer from "./ducks/computer_vision_demo";
import ComputerVisionDemo from "./containers/computer_vision_demo";

const rootReducer = combineReducers( {
  computerVisionDemo: computerVisionDemoReducer
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

render(
  <Provider store={store}>
    <ComputerVisionDemo />
  </Provider>,
  document.getElementById( "app" )
);
