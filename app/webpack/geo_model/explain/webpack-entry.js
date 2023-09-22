import _ from "lodash";
import "core-js/stable";
import "regenerator-runtime/runtime";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import {
  createStore, compose, applyMiddleware, combineReducers
} from "redux";
import inatjs from "inaturalistjs";
import AppContainer from "./containers/app_container";
import configReducer, { setConfig } from "../../shared/ducks/config";
import taxonReducer, { setTaxon } from "../../taxa/shared/ducks/taxon";

const { Taxon } = inatjs;

const rootReducer = combineReducers( {
  config: configReducer,
  taxon: taxonReducer
} );

const store = createStore(
  rootReducer,
  compose( ..._.compact( [
    applyMiddleware( thunkMiddleware ),
    // enable Redux DevTools if available
    window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
  ] ) )
);

if ( CURRENT_USER !== undefined && CURRENT_USER !== null ) {
  store.dispatch( setConfig( {
    currentUser: CURRENT_USER
  } ) );
}

/* global SERVER_PAYLOAD */
const serverPayload = SERVER_PAYLOAD;

const taxon = new Taxon( serverPayload.taxon );
store.dispatch( setTaxon( taxon ) );

google.maps.importLibrary( "maps" ).then( ( ) => (
  google.maps.importLibrary( "drawing" )
) ).then( ( ) => (
  google.maps.importLibrary( "geometry" )
) ).then( ( ) => (
  google.maps.importLibrary( "places" )
) )
  .then( ( ) => {
    /* global loadMap3 */
    loadMap3( );
    render(
      <Provider store={store}>
        <AppContainer />
      </Provider>,
      document.getElementById( "app" )
    );
  } );
