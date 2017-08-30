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
  updateSearchParamsWithoutHistory,
  updateDefaultParams
} from "./actions/";
import { fetchAllControlledTerms } from "../show/ducks/controlled_terms";
import AppContainer from "./containers/app_container";
import _ from "lodash";


// Use custom relative times for moment
const shortRelativeTime = I18n.t( "momentjs" ) ? I18n.t( "momentjs" ).shortRelativeTime : null;
const relativeTime = Object.assign(
  {},
  I18n.t( "momentjs", { locale: "en" } ).shortRelativeTime,
  shortRelativeTime
);
moment.locale( I18n.locale );
moment.updateLocale( moment.locale(), { relativeTime } );

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
  store.dispatch( updateSearchParamsWithoutHistory( e.state ) );
  store.dispatch( fetchObservationsStats() );
};

// Set state from initial url search and listen for changes
// Order is important, this needs to happen before any other actions are dispatched.
const urlParams = $.deparam( window.location.search.replace( /^\?/, "" ) );
const newParams = normalizeParams( urlParams );
if ( urlParams.hasOwnProperty( "blind" ) ) {
  store.dispatch( setConfig( { blind: true } ) );
}
store.dispatch( updateSearchParamsWithoutHistory( newParams ) );
store.dispatch( fetchAllControlledTerms( ) );

// Somewhat magic, so be advised: binding a a couple actions to changes in
// particular parts of the state. Might belong elsewhere, but this is where we
// have access to the store
function observeStore( storeToObserve, select, onChange ) {
  let currentState;
  function handleChange() {
    const nextState = select( storeToObserve.getState( ) );
    if ( !_.isEqual( nextState, currentState ) ) {
      currentState = nextState;
      onChange( currentState );
    }
  }
  const unsubscribe = storeToObserve.subscribe( handleChange );
  handleChange( );
  return unsubscribe;
}
// Fetch observations when the params change
observeStore( store, s => s.searchParams.params, ( ) => {
  store.dispatch( fetchObservations( ) );
} );


render(
  <Provider store={store}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
