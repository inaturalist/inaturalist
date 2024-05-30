import _ from "lodash";
import "core-js/stable";
import "regenerator-runtime/runtime";
import thunkMiddleware from "redux-thunk";
import {
  applyMiddleware,
  combineReducers,
  compose,
  createStore
} from "redux";
import React from "react";
import moment from "moment";
import { render } from "react-dom";
import { Provider } from "react-redux";

import languageDemoReducer, { languageSearch, fetchIconicTaxa } from "./reducers/language_demo_reducer";
import LanguageDemoContainer from "./containers/language_demo_container";
import confirmModalReducer from "../../observations/show/ducks/confirm_modal";
import configReducer, { setConfig } from "../../shared/ducks/config";

moment.locale( I18n.locale );

const rootReducer = combineReducers( {
  languageDemo: languageDemoReducer,
  confirmModal: confirmModalReducer,
  config: configReducer
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
  store.dispatch( setConfig( { currentUser: CURRENT_USER } ) );
}

store.dispatch( fetchIconicTaxa( ) );

render(
  <Provider store={store}>
    <LanguageDemoContainer />
  </Provider>,
  document.getElementById( "app" )
);
