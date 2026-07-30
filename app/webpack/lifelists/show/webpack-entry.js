import _ from "lodash";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import inatjs from "inaturalistjs";
import AppContainer from "./containers/app_container";
import lifelistReducer, { fetchUser, updateWithHistoryState } from "./reducers/lifelist";
import exportModalReducer from "./reducers/export_modal";
import { setConfig, setCurrentUser } from "../../shared/ducks/config";
import inatAPIReducer from "../../shared/ducks/inat_api_duck";
import sharedStore from "../../shared/shared_store";

sharedStore.injectReducers( {
  lifelist: lifelistReducer,
  inatAPI: inatAPIReducer,
  exportModal: exportModalReducer
} );

if ( !_.isEmpty( CURRENT_USER ) ) {
  sharedStore.dispatch( setCurrentUser( CURRENT_USER ) );
}

if ( !_.isEmpty( SITE ) ) {
  sharedStore.dispatch( setConfig( {
    site: SITE
  } ) );
}

if ( !_.isEmpty( PREFERRED_PLACE ) ) {
  // we use this for requesting localized taxon names
  sharedStore.dispatch( setConfig( {
    preferredPlace: PREFERRED_PLACE
  } ) );
}

const element = document.querySelector( "meta[name=\"config:inaturalist_api_url\"]" );
const defaultApiUrl = element && element.getAttribute( "content" );
if ( defaultApiUrl ) {
  sharedStore.dispatch( setConfig( {
    testingApiV2: true
  } ) );
  inatjs.setConfig( {
    apiURL: defaultApiUrl.replace( "/v1", "/v2" ),
    writeApiURL: defaultApiUrl.replace( "/v1", "/v2" )
  } );
}

/* global LIFELIST_USER */
sharedStore.dispatch( fetchUser( LIFELIST_USER, {
  callback: ( ) => {
    render(
      <Provider store={sharedStore}>
        <AppContainer />
      </Provider>,
      document.getElementById( "app" )
    );
  }
} ) );

window.onpopstate = e => {
  sharedStore.dispatch( updateWithHistoryState( e.state ) );
};
