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
  updateSearchParamsFromPop,
  updateDefaultParams
} from "./actions/";
import App from "./components/app";

// Use custom relative times for moment
const shortRelativeTime = I18n.t( "momentjs" ) ? I18n.t( "momentjs" ).shortRelativeTime : null;
moment.locale( I18n.locale, {
  relativeTime: shortRelativeTime
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


// Set state from initial url search and listen for changes
// Order is important, this needs to happen before any other actions are dispatched.
const newParams = normalizeParams(
  $.deparam( window.location.search.replace( /^\?/, "" ) )
);
store.dispatch( updateSearchParams( newParams ) );

if ( CURRENT_USER !== undefined && CURRENT_USER !== null ) {
  store.dispatch( setConfig( {
    currentUser: CURRENT_USER
  } ) );
}

if ( PREFERRED_PLACE !== undefined && PREFERRED_PLACE !== null ) {
  // we use this for requesting localized taoxn names
  store.dispatch( setConfig( {
    preferredPlace: PREFERRED_PLACE
  } ) );
  // this is the default place for all obs API requests
  store.dispatch( updateDefaultParams( {
    place_id: PREFERRED_PLACE.id
  } ) );
}

setupKeyboardShortcuts( store.dispatch );

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
