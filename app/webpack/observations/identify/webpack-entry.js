import moment from "moment";
import inatjs from "inaturalistjs";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import _ from "lodash";
import setupKeyboardShortcuts from "./keyboard_shortcuts";
import reducers from "./reducers";
import { normalizeParams } from "./reducers/search_params_reducer";
import {
  fetchObservations,
  fetchObservationsStats,
  setConfig,
  setCurrentUser,
  updateSearchParamsWithoutHistory,
  updateDefaultParams
} from "./actions";
import { fetchAllControlledTerms } from "../show/ducks/controlled_terms";
import AppContainer from "./containers/app_container";
import sharedStore from "../../shared/shared_store";

sharedStore.injectReducers( reducers );

// Use custom relative times for moment
const shortRelativeTime = I18n.t( "momentjs" ) ? I18n.t( "momentjs" ).shortRelativeTime : null;
const relativeTime = {
  ...I18n.t( "momentjs", { locale: "en" } ).shortRelativeTime,
  ...shortRelativeTime
};
moment.locale( I18n.locale );
moment.updateLocale( moment.locale(), { relativeTime } );

const testingApiV2 = ( CURRENT_USER.testGroups && CURRENT_USER.testGroups.includes( "apiv2" ) )
  || window.location.search.match( /test=apiv2/ );

if ( !_.isEmpty( CURRENT_USER ) ) {
  sharedStore.dispatch( setCurrentUser( CURRENT_USER ) );
}

if ( PREFERRED_PLACE !== undefined && PREFERRED_PLACE !== null ) {
  // we use this for requesting localized taxon names
  sharedStore.dispatch( setConfig( {
    preferredPlace: PREFERRED_PLACE
  } ) );
}

if ( PREFERRED_SEARCH_PLACE !== undefined && PREFERRED_SEARCH_PLACE !== null ) {
  // this is the default place for all obs API requests
  sharedStore.dispatch( updateDefaultParams( {
    place_id: testingApiV2 ? PREFERRED_SEARCH_PLACE.uuid : PREFERRED_SEARCH_PLACE.id
  } ) );
}

if ( OFFICIAL_APP_IDS !== undefined && OFFICIAL_APP_IDS !== null ) {
  // set apps that will display icons in the observation modal
  sharedStore.dispatch( setConfig( {
    officialAppIds: OFFICIAL_APP_IDS
  } ) );
}

if ( testingApiV2 ) {
  const element = document.querySelector( "meta[name=\"config:inaturalist_api_url\"]" );
  const defaultApiUrl = element && element.getAttribute( "content" );
  if ( defaultApiUrl ) {
    sharedStore.dispatch( setConfig( {
      testingApiV2: true
    } ) );
    // For some reason this seems to set it everywhere...
    inatjs.setConfig( {
      apiURL: defaultApiUrl.replace( "/v1", "/v2" ),
      writeApiURL: defaultApiUrl.replace( "/v1", "/v2" )
    } );
  }
}

setupKeyboardShortcuts( sharedStore.dispatch );

window.onpopstate = e => {
  sharedStore.dispatch( updateSearchParamsWithoutHistory( e.state ) );
  sharedStore.dispatch( fetchObservationsStats() );
};

// Set state from initial url search and listen for changes
// Order is important, this needs to happen before any other actions are dispatched.
const urlParams = $.deparam( window.location.search.replace( /^\?/, "" ) );
const newParams = normalizeParams( urlParams );
if ( urlParams.hasOwnProperty( "blind" ) ) {
  sharedStore.dispatch( setConfig( { blind: true, sideBarHidden: false } ) );
} else {
  sharedStore.dispatch( setConfig( { sideBarHidden: !CURRENT_USER.prefers_identify_side_bar } ) );
}
sharedStore.dispatch( setConfig( { imageSize: CURRENT_USER.preferred_identify_image_size } ) );
sharedStore.dispatch( updateSearchParamsWithoutHistory( newParams ) );
sharedStore.dispatch( fetchAllControlledTerms( ) );

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
// Fetch observations when the params change, with a small delay so only
// one search is performed if parameters change quickly
let lastSearchTime;
observeStore( sharedStore, s => s.searchParams.params, ( ) => {
  const thisSearchTime = Date.now( );
  lastSearchTime = thisSearchTime;
  setTimeout( ( ) => {
    if ( thisSearchTime !== lastSearchTime ) {
      return;
    }
    sharedStore.dispatch( fetchObservations( ) );
  }, 1000 );
} );

render(
  <Provider store={sharedStore}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
