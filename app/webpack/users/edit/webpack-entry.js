import moment from "moment";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import inatjs from "inaturalistjs";
import alertModal from "../../shared/ducks/alert_modal";
import { setConfig } from "../../shared/ducks/config";
import userSettingsReducer, { fetchUserSettings } from "./ducks/user_settings";
import sectionReducer, { setSelectedSectionFromHash } from "./ducks/app_sections";
import sitesReducer, { fetchNetworkSites } from "./ducks/network_sites";
import revokeAccessModalReducer from "./ducks/revoke_access_modal";
import deleteRelationshipModalReducer from "./ducks/delete_relationship_modal";
import authenticatedAppsReducer, { fetchAuthorizedApps, fetchProviderApps } from "./ducks/authorized_applications";
import relationshipsReducer from "./ducks/relationships";
import creativeCommonsLicensingModalReducer from "./ducks/cc_licensing_modal";
import confirmModalReducer from "../../observations/show/ducks/confirm_modal";
import AppContainer from "./containers/app_container";
import sharedStore from "../../shared/shared_store";

moment.locale( I18n.locale );

sharedStore.injectReducers( {
  profile: userSettingsReducer,
  sites: sitesReducer,
  revokeAccess: revokeAccessModalReducer,
  deleteRelationship: deleteRelationshipModalReducer,
  apps: authenticatedAppsReducer,
  relationships: relationshipsReducer,
  creativeCommonsLicensing: creativeCommonsLicensingModalReducer,
  section: sectionReducer,
  confirmModal: confirmModalReducer,
  alertModal
} );

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

if ( window.location.hash ) {
  sharedStore.dispatch( setSelectedSectionFromHash( window.location.hash ) );
}

window.onpopstate = e => {
  const { hash } = e.target.location;
  sharedStore.dispatch( setSelectedSectionFromHash( hash ) );
};

sharedStore.dispatch( fetchUserSettings( null ) );
sharedStore.dispatch( fetchNetworkSites( ) );
sharedStore.dispatch( fetchAuthorizedApps( ) );
sharedStore.dispatch( fetchProviderApps( ) );

render(
  // eslint-disable-next-line react/jsx-filename-extension
  <Provider store={sharedStore}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
