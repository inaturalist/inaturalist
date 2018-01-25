import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import { createStore, compose, applyMiddleware } from "redux";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import _ from "lodash";

import reducer from "./reducers";
import Uploader from "./containers/uploader";
import actions from "./actions/actions";

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

if ( !_.isEmpty( CURRENT_USER ) ) {
  store.dispatch( actions.setState( {
    config: {
      currentUser: CURRENT_USER
    }
  } ) );
}

render(
  <Provider store={store}>
    <Uploader />
  </Provider>,
  document.getElementById( "app" )
);
