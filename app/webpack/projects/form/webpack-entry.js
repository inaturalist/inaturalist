import _ from "lodash";
import React from "react";
import moment from "moment";
import { render } from "react-dom";
import { Provider } from "react-redux";
import AppContainer from "./containers/app_container";
import { setCurrentUser } from "../../shared/ducks/config";
import formReducer, { setProject, setCopyProject } from "./form_reducer";
import confirmModalReducer from "../../shared/ducks/confirm_modal";
import controlledTermsReducer, { fetchAllControlledTerms }
  from "../../observations/show/ducks/controlled_terms";
import sharedStore from "../../shared/shared_store";
/* global CURRENT_PROJECT */
/* global COPY_PROJECT */

moment.locale( I18n.locale );

sharedStore.injectReducers( {
  confirmModal: confirmModalReducer,
  form: formReducer,
  controlledTerms: controlledTermsReducer
} );

if ( !_.isEmpty( CURRENT_USER ) ) {
  sharedStore.dispatch( setCurrentUser( CURRENT_USER ) );
}

if ( !_.isEmpty( CURRENT_PROJECT ) ) {
  sharedStore.dispatch( setProject( CURRENT_PROJECT ) );
} else if ( !_.isEmpty( COPY_PROJECT ) ) {
  sharedStore.dispatch( setCopyProject( COPY_PROJECT ) );
}

sharedStore.dispatch( fetchAllControlledTerms( ) );

render(
  <Provider store={sharedStore}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
