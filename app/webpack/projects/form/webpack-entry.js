import _ from "lodash";
import "core-js/stable";
import "regenerator-runtime/runtime";
import thunkMiddleware from "redux-thunk";
import React from "react";
import moment from "moment";
import { render } from "react-dom";
import { Provider } from "react-redux";
import {
  createStore, compose, applyMiddleware, combineReducers
} from "redux";
import AppContainer from "./containers/app_container";
import configReducer, { setConfig } from "../../shared/ducks/config";
import formReducer, { setProject, setCopyProject } from "./form_reducer";
import confirmModalReducer from "../../observations/show/ducks/confirm_modal";
import controlledTermsReducer, { fetchAllControlledTerms }
  from "../../observations/show/ducks/controlled_terms";
/* global CURRENT_PROJECT */
/* global COPY_PROJECT */

moment.locale( I18n.locale );

const rootReducer = combineReducers( {
  confirmModal: confirmModalReducer,
  config: configReducer,
  form: formReducer,
  controlledTerms: controlledTermsReducer
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

if ( !_.isEmpty( CURRENT_PROJECT ) ) {
  store.dispatch( setProject( CURRENT_PROJECT ) );
} else if ( !_.isEmpty( COPY_PROJECT ) ) {
  store.dispatch( setCopyProject( COPY_PROJECT ) );
}

store.dispatch( fetchAllControlledTerms( ) );

render(
  <Provider store={store}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
