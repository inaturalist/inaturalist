import "core-js/stable";
import "regenerator-runtime/runtime";
import moment from "moment";
import inatjs from "inaturalistjs";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware } from "redux";
import _ from "lodash";
import setupKeyboardShortcuts from "./keyboard_shortcuts";
import rootReducer from "./reducers";
import { normalizeParams } from "./reducers/search_params_reducer";
import {
  fetchObservations,
  fetchObservationsStats,
  setConfig,
  updateSearchParamsWithoutHistory,
  updateDefaultParams
} from "./actions";
import { fetchAllControlledTerms } from "../show/ducks/controlled_terms";
import AppContainer from "./containers/app_container";

// Use custom relative times for moment
const shortRelativeTime = I18n.t( "momentjs" ) ? I18n.t( "momentjs" ).shortRelativeTime : null;
const relativeTime = {
  ...I18n.t( "momentjs", { locale: "en" } ).shortRelativeTime,
  ...shortRelativeTime
};
moment.locale( I18n.locale );
moment.updateLocale( moment.locale(), { relativeTime } );

const store = createStore(
  rootReducer,
  compose( ..._.compact( [
    applyMiddleware( thunkMiddleware ),
    // enable Redux DevTools if available
    window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
  ] ) )
);

const testingApiV2 = ( CURRENT_USER.testGroups && CURRENT_USER.testGroups.includes( "apiv2" ) )
  || window.location.search.match( /test=apiv2/ );

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
}

if ( PREFERRED_SEARCH_PLACE !== undefined && PREFERRED_SEARCH_PLACE !== null ) {
  // this is the default place for all obs API requests
  store.dispatch( updateDefaultParams( {
    place_id: testingApiV2 ? PREFERRED_SEARCH_PLACE.uuid : PREFERRED_SEARCH_PLACE.id
  } ) );
}

if ( OFFICIAL_APP_IDS !== undefined && OFFICIAL_APP_IDS !== null ) {
  // set apps that will display icons in the observation modal
  store.dispatch( setConfig( {
    officialAppIds: OFFICIAL_APP_IDS
  } ) );
}

if ( testingApiV2 ) {
  const element = document.querySelector( "meta[name=\"config:inaturalist_api_url\"]" );
  const defaultApiUrl = element && element.getAttribute( "content" );
  if ( defaultApiUrl ) {
    store.dispatch( setConfig( {
      testingApiV2: true
    } ) );
    // For some reason this seems to set it everywhere...
    inatjs.setConfig( {
      apiURL: defaultApiUrl.replace( "/v1", "/v2" ),
      writeApiURL: defaultApiUrl.replace( "/v1", "/v2" )
    } );
  }
}

setupKeyboardShortcuts( store.dispatch );

window.onpopstate = e => {
  store.dispatch( updateSearchParamsWithoutHistory( e.state ) );
  store.dispatch( fetchObservationsStats() );
};

// Set state from initial url search and listen for changes
// Order is important, this needs to happen before any other actions are dispatched.
const urlParams = $.deparam( window.location.search.replace( /^\?/, "" ) );
const newParams = normalizeParams( urlParams );
if ( urlParams.hasOwnProperty( "blind" ) ) {
  store.dispatch( setConfig( { blind: true, sideBarHidden: false } ) );
} else {
  store.dispatch( setConfig( { sideBarHidden: !CURRENT_USER.prefers_identify_side_bar } ) );
}
store.dispatch( setConfig( { imageSize: CURRENT_USER.preferred_identify_image_size } ) );
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
