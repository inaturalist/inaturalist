import "@babel/polyfill";
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

import userSettingsReducer, { fetchUserSettings } from "./ducks/user_settings";
import revokeAccessModalReducer from "./ducks/revoke_access_modal";
import authenticatedAppsReducer, { fetchAuthorizedApps } from "./ducks/authorized_applications";
import thirdPartyTrackingModalReducer from "./ducks/third_party_tracking_modal";
import aboutLicensingModalReducer from "./ducks/about_licensing_modal";
import AppContainer from "./containers/app_container";

const rootReducer = combineReducers( {
  profile: userSettingsReducer,
  revokeAccess: revokeAccessModalReducer,
  apps: authenticatedAppsReducer,
  thirdPartyTracking: thirdPartyTrackingModalReducer,
  aboutLicensing: aboutLicensingModalReducer
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

store.dispatch( fetchUserSettings( null ) );
store.dispatch( fetchAuthorizedApps( ) );

render(
  // eslint-disable-next-line react/jsx-filename-extension
  <Provider store={store}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
