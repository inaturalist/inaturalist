import _ from "lodash";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import inatjs from "inaturalistjs";
import AppContainer from "./containers/app_container";
import { setConfig, setCurrentUser } from "../../shared/ducks/config";
import projectReducer, {
  setProject,
  fetchOverviewData,
  setSelectedTab,
  fetchCurrentProjectUser
} from "./ducks/project";
import photoModalReducer from "../../taxa/shared/ducks/photo_modal";
import confirmModalReducer from "../../shared/ducks/confirm_modal";
import flaggingModalReducer from "../../observations/show/ducks/flagging_modal";
import sharedStore from "../../shared/shared_store";
/* global PROJECT_DATA */
/* global CURRENT_TAB */
/* global CURRENT_SUBTAB */

sharedStore.injectReducers( {
  project: projectReducer,
  photoModal: photoModalReducer,
  confirmModal: confirmModalReducer,
  flaggingModal: flaggingModalReducer
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
  inatjs.setConfig( {
    apiURL: defaultApiUrl.replace( "/v1", "/v2" ),
    writeApiURL: defaultApiUrl.replace( "/v1", "/v2" )
  } );
}

sharedStore.dispatch( setProject( PROJECT_DATA ) );
sharedStore.dispatch( setSelectedTab(
  CURRENT_TAB,
  { subtab: CURRENT_SUBTAB, replaceState: true }
) );
sharedStore.dispatch( fetchCurrentProjectUser( ) );
sharedStore.dispatch( fetchOverviewData( ) );

render(
  <Provider store={sharedStore}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);

window.onpopstate = e => {
  sharedStore.dispatch( setSelectedTab( e.state.selectedTab, { skipState: true } ) );
};
