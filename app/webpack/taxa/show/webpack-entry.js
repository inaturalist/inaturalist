import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware, combineReducers } from "redux";
import { Taxon } from "inaturalistjs";
import AppContainer from "./containers/app_container";
import configReducer, { setConfig } from "../../shared/ducks/config";
import taxonReducer, { setTaxon, fetchTaxon, setCount } from "../shared/ducks/taxon";
import observationsReducer, {
  fetchMonthFrequency,
  fetchMonthOfYearFrequency
} from "./ducks/observations";
import leadersReducer, { fetchLeaders } from "./ducks/leaders";
import photoModalReducer from "../shared/ducks/photo_modal";

const rootReducer = combineReducers( {
  config: configReducer,
  taxon: taxonReducer,
  observations: observationsReducer,
  leaders: leadersReducer,
  photoModal: photoModalReducer
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

const taxon = new Taxon( TAXON );
store.dispatch( setTaxon( taxon ) );
if ( taxon.taxon_changes_count ) {
  store.dispatch( setCount( "taxonChangesCount", taxon.taxon_changes_count ) );
}
if ( taxon.taxon_schemes_count ) {
  store.dispatch( setCount( "taxonSchemesCount", taxon.taxon_schemes_count ) );
}
store.dispatch( fetchLeaders( taxon ) ).then( ( ) => {
  store.dispatch( fetchMonthOfYearFrequency( taxon ) ).then( ( ) => {
    store.dispatch( fetchMonthFrequency( taxon ) );
  } );
} );

window.onpopstate = ( ) => {
  // user returned from BACK
};

render(
  <Provider store={store}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
