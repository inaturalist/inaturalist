import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware, combineReducers } from "redux";
import AppContainer from "./containers/app_container";
import configReducer, { setConfig } from "./ducks/config";
import taxonReducer, { setTaxon, fetchTaxon, setCount } from "./ducks/taxon";
import observationsReducer, {
  fetchMonthFrequency,
  fetchMonthOfYearFrequency
} from "./ducks/observations";
import leadersReducer, { fetchLeaders } from "./ducks/leaders";
import interactionsReducer from "./ducks/interactions";
import photoModalReducer from "./ducks/photo_modal";

const rootReducer = combineReducers( {
  config: configReducer,
  taxon: taxonReducer,
  observations: observationsReducer,
  leaders: leadersReducer,
  photoModal: photoModalReducer,
  interactions: interactionsReducer
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
  if ( TAXON.taxon_changes_count ) {
    store.dispatch( setCount( "taxonChangesCount", TAXON.taxon_changes_count) );
  }
  if ( TAXON.taxon_schemes_count ) {
    store.dispatch( setCount( "taxonSchemesCount", TAXON.taxon_schemes_count) );
  }
  store.dispatch( fetchTaxon( TAXON ) );
  store.dispatch( fetchMonthFrequency( TAXON ) );
  store.dispatch( fetchMonthOfYearFrequency( TAXON ) );
  store.dispatch( fetchLeaders( TAXON ) );
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
