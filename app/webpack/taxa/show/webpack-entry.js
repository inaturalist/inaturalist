import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware, combineReducers } from "redux";
import AppContainer from "./containers/app_container";
import configReducer, { setConfig } from "./ducks/config";
import taxonReducer, { setTaxon, fetchTaxon } from "./ducks/taxon";
import observationsReducer, {
  fetchMonthFrequency,
  fetchMonthOfYearFrequency
} from "./ducks/observations";
import leadersReducer, { fetchLeaders } from "./ducks/leaders";

const rootReducer = combineReducers( {
  config: configReducer,
  taxon: taxonReducer,
  observations: observationsReducer,
  leaders: leadersReducer
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

if ( CURRENT_USER !== undefined && CURRENT_USER !== null ) {
  store.dispatch( setConfig( {
    currentUser: CURRENT_USER
  } ) );
}

if ( PREFERRED_PLACE !== undefined && PREFERRED_PLACE !== null ) {
  // we use this for requesting localized taoxn names
  store.dispatch( setConfig( {
    preferredPlace: PREFERRED_PLACE
  } ) );
}

if ( TAXON !== undefined && TAXON !== null ) {
  store.dispatch( setTaxon( TAXON ) );
  store.dispatch( fetchTaxon( TAXON ) );
  store.dispatch( fetchMonthFrequency( ) );
  store.dispatch( fetchMonthOfYearFrequency( ) );
  store.dispatch( fetchLeaders( ) );
}

window.onpopstate = ( ) => {
  // user returned from BACK
};

render(
  <Provider store={store}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
