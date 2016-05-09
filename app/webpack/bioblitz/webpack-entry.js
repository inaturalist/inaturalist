import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import { createStore, compose, applyMiddleware } from "redux";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";

import reducer from "./reducers";
import BioblitzContainer from "./containers/bioblitz_container";

const store = createStore(
  reducer,
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
    <BioblitzContainer />
  </Provider>,
  document.getElementById( "app" )
);
