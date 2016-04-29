import "babel-polyfill";
import moment from "moment";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware } from "redux";
import setupKeyboardShortcuts from "./keyboard_shortcuts";
import rootReducer from "./reducers/";
import { normalizeParams } from "./reducers/search_params_reducer";
import {
  fetchObservations,
  fetchObservationsStats,
  setConfig,
  updateSearchParams,
  updateSearchParamsFromPop
} from "./actions/";
import App from "./components/app";

// Use custom relative times for moment
moment.locale( I18n.locale, {
  relativeTime: I18n.translations[I18n.locale].momentjs.shortRelativeTime
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

if ( CURRENT_USER !== undefined && CURRENT_USER !== null ) {
  store.dispatch( setConfig( {
    currentUser: CURRENT_USER
  } ) );
}

setupKeyboardShortcuts( store.dispatch );

// set state from initial url search and listen for changes
const newParams = normalizeParams(
  $.deparam( window.location.search.replace( /^\?/, "" ) )
);
store.dispatch( updateSearchParams( newParams ) );
window.onpopstate = ( e ) => {
  store.dispatch( updateSearchParamsFromPop( e.state ) );
  store.dispatch( fetchObservations() );
  store.dispatch( fetchObservationsStats() );
};

// retrieve initial set of observations
store.dispatch( fetchObservations() );
store.dispatch( fetchObservationsStats() );

render(
  <Provider store={store}>
    <App />
  </Provider>,
  document.getElementById( "app" )
);
