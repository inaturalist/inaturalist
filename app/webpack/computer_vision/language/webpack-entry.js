import React from "react";
import moment from "moment";
import { render } from "react-dom";
import { Provider } from "react-redux";
import inatjs from "inaturalistjs";

import languageDemoReducer, {
  fetchIconicTaxa,
  matchBrowserState,
  loadFromURL
} from "./reducers/language_demo_reducer";
import LanguageDemoContainer from "./containers/language_demo_container";
import confirmModalReducer from "../../shared/ducks/confirm_modal";
import { setConfig } from "../../shared/ducks/config";
import sharedStore from "../../shared/shared_store";

moment.locale( I18n.locale );

sharedStore.injectReducers( {
  languageDemo: languageDemoReducer,
  confirmModal: confirmModalReducer
} );

const element = document.querySelector( "meta[name=\"config:inaturalist_api_url\"]" );
const defaultApiUrl = element && element.getAttribute( "content" );
inatjs.setConfig( {
  apiURL: defaultApiUrl.replace( "/v1", "/v2" ),
  writeApiURL: defaultApiUrl.replace( "/v1", "/v2" )
} );
sharedStore.dispatch( setConfig( { testingApiV2: true } ) );

sharedStore.dispatch( fetchIconicTaxa( ) );

render(
  <Provider store={sharedStore}>
    <LanguageDemoContainer />
  </Provider>,
  document.getElementById( "app" )
);

sharedStore.dispatch( loadFromURL( ) );

window.onpopstate = e => {
  sharedStore.dispatch( matchBrowserState( e.state || { } ) );
};
