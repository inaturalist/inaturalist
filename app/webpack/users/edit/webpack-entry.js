import _ from "lodash";
import "core-js/stable";
import moment from "moment";
import "regenerator-runtime/runtime";
import React from "react";
import { render } from "react-dom";
import thunkMiddleware from "redux-thunk";
import { Provider } from "react-redux";
import {
  createStore,
  compose,
  applyMiddleware,
  combineReducers
} from "redux";

import inatjs from "inaturalistjs";
import alertModal from "../../shared/ducks/alert_modal";
import configReducer, { setConfig } from "../../shared/ducks/config";
import userSettingsReducer, { fetchUserSettings } from "./ducks/user_settings";
import sectionReducer, { setSelectedSectionFromHash } from "./ducks/app_sections";
import sitesReducer, { fetchNetworkSites } from "./ducks/network_sites";
import revokeAccessModalReducer from "./ducks/revoke_access_modal";
import deleteRelationshipModalReducer from "./ducks/delete_relationship_modal";
import authenticatedAppsReducer, { fetchAuthorizedApps, fetchProviderApps } from "./ducks/authorized_applications";
import relationshipsReducer from "./ducks/relationships";
import thirdPartyTrackingModalReducer from "./ducks/third_party_tracking_modal";
import creativeCommonsLicensingModalReducer from "./ducks/cc_licensing_modal";
import confirmModalReducer from "../../observations/show/ducks/confirm_modal";
import AppContainer from "./containers/app_container";

moment.locale( I18n.locale );

const rootReducer = combineReducers( {
  config: configReducer,
  profile: userSettingsReducer,
  sites: sitesReducer,
  revokeAccess: revokeAccessModalReducer,
  deleteRelationship: deleteRelationshipModalReducer,
  apps: authenticatedAppsReducer,
  relationships: relationshipsReducer,
  thirdPartyTracking: thirdPartyTrackingModalReducer,
  creativeCommonsLicensing: creativeCommonsLicensingModalReducer,
  section: sectionReducer,
  confirmModal: confirmModalReducer,
  alertModal
} );

const store = createStore(
  rootReducer,
  compose( ..._.compact( [
    applyMiddleware( thunkMiddleware ),
    // enable Redux DevTools if available
    window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__( )
  ] ) )
);

if ( CURRENT_USER !== undefined && CURRENT_USER !== null ) {
  store.dispatch( setConfig( {
    currentUser: CURRENT_USER
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

if ( window.location.hash ) {
  store.dispatch( setSelectedSectionFromHash( window.location.hash ) );
}

window.onpopstate = e => {
  const { hash } = e.target.location;
  store.dispatch( setSelectedSectionFromHash( hash ) );
};

store.dispatch( fetchUserSettings( null ) );
store.dispatch( fetchNetworkSites( ) );
store.dispatch( fetchAuthorizedApps( ) );
store.dispatch( fetchProviderApps( ) );

render(
  // eslint-disable-next-line react/jsx-filename-extension
  <Provider store={store}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
