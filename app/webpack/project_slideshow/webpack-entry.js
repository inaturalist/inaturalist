import _ from "lodash";
import "core-js/stable";
import "regenerator-runtime/runtime";
import thunkMiddleware from "redux-thunk";
import { createStore, compose, applyMiddleware } from "redux";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";

import reducer from "./reducers";
import SlideshowContainer from "./containers/slideshow_container";

const store = createStore(
  reducer,
  compose( ..._.compact( [
    applyMiddleware( thunkMiddleware ),
    // enable Redux DevTools if available
    window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
  ] ) )
);

render(
  <Provider store={store}>
    <SlideshowContainer />
  </Provider>,
  document.getElementById( "app" )
);
