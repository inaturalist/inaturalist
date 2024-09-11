import _ from "lodash";
import "core-js/stable";
import "regenerator-runtime/runtime";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import {
  createStore,
  compose,
  applyMiddleware,
  combineReducers
} from "redux";
import inatjs from "inaturalistjs";
import AppContainer from "./containers/app_container";
import configReducer, { setConfig } from "../../shared/ducks/config";
import projectReducer, {
  setProject,
  fetchOverviewData,
  setSelectedTab,
  fetchCurrentProjectUser
} from "./ducks/project";
import photoModalReducer from "../../taxa/shared/ducks/photo_modal";
import confirmModalReducer from "../../observations/show/ducks/confirm_modal";
import flaggingModalReducer from "../../observations/show/ducks/flagging_modal";
/* global PROJECT_DATA */
/* global CURRENT_TAB */
/* global CURRENT_SUBTAB */
/* global SITE */

const rootReducer = combineReducers( {
  config: configReducer,
  project: projectReducer,
  photoModal: photoModalReducer,
  confirmModal: confirmModalReducer,
  flaggingModal: flaggingModalReducer
} );

const store = createStore(
  rootReducer,
  compose( ..._.compact( [
    applyMiddleware( thunkMiddleware ),
    // enable Redux DevTools if available
    window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
  ] ) )
);

if ( !_.isEmpty( CURRENT_USER ) ) {
  store.dispatch( setConfig( {
    currentUser: CURRENT_USER
  } ) );
}

if ( !_.isEmpty( SITE ) ) {
  store.dispatch( setConfig( {
    site: SITE
  } ) );
}

if ( !_.isEmpty( PREFERRED_PLACE ) ) {
  // we use this for requesting localized taxon names
  store.dispatch( setConfig( {
    preferredPlace: PREFERRED_PLACE
  } ) );
}

if (
  ( CURRENT_USER.testGroups && CURRENT_USER.testGroups.includes( "apiv2" ) )
  || window.location.search.match( /test=apiv2/ )
) {
  const element = document.querySelector( "meta[name=\"config:inaturalist_api_url\"]" );
  const defaultApiUrl = element && element.getAttribute( "content" );
  if ( defaultApiUrl ) {
    store.dispatch( setConfig( {
      testingApiV2: true
    } ) );
    inatjs.setConfig( {
      apiURL: defaultApiUrl.replace( "/v1", "/v2" ),
      writeApiURL: defaultApiUrl.replace( "/v1", "/v2" )
    } );
  }
}

store.dispatch( setProject( PROJECT_DATA ) );
store.dispatch( setSelectedTab( CURRENT_TAB, { subtab: CURRENT_SUBTAB, replaceState: true } ) );
store.dispatch( fetchCurrentProjectUser( ) );
store.dispatch( fetchOverviewData( ) );

render(
  <Provider store={store}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);

window.onpopstate = e => {
  store.dispatch( setSelectedTab( e.state.selectedTab, { skipState: true } ) );
};
