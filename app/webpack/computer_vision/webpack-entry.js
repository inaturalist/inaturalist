import _ from "lodash";
import "@babel/polyfill";
import thunkMiddleware from "redux-thunk";
import {
  applyMiddleware,
  combineReducers,
  compose,
  createStore
} from "redux";
import React from "react";
import moment from "moment";
import { render } from "react-dom";
import { Provider } from "react-redux";

import computerVisionDemoReducer from "./ducks/computer_vision_demo";
import ComputerVisionDemo from "./containers/computer_vision_demo";

moment.locale( I18n.locale );

const rootReducer = combineReducers( {
  computerVisionDemo: computerVisionDemoReducer
} );

const store = createStore(
  rootReducer,
  compose( ..._.compact( [
    applyMiddleware( thunkMiddleware ),
    // enable Redux DevTools if available
    window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
  ] ) )
);

render(
  <Provider store={store}>
    <ComputerVisionDemo />
  </Provider>,
  document.getElementById( "app" )
);
