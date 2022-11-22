import "@babel/polyfill";
import thunkMiddleware from "redux-thunk";
import { createStore, compose, applyMiddleware } from "redux";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import _ from "lodash";
import moment from "moment";

import reducer from "./reducers";
import Uploader from "./containers/uploader";
import { setConfig } from "../../shared/ducks/config";
import { fetchSavedLocations } from "./ducks/saved_locations";

moment.locale( I18n.locale );

const store = createStore(
  reducer,
  compose( ..._.compact( [
    applyMiddleware( thunkMiddleware ),
    // enable Redux DevTools if available
    window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
  ] ) )
);

if ( !_.isEmpty( CURRENT_USER ) ) {
  store.dispatch( setConfig( { currentUser: CURRENT_USER } ) );
  store.dispatch( fetchSavedLocations( ) );
}

render(
  <Provider store={store}>
    <Uploader />
  </Provider>,
  document.getElementById( "app" )
);
