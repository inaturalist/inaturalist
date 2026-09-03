import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import inatjs from "inaturalistjs";
import AppContainer from "./containers/app_container";
import taxonReducer, { setTaxon } from "../../taxa/shared/ducks/taxon";
import sharedStore from "../../shared/shared_store";

const { Taxon } = inatjs;

sharedStore.injectReducers( {
  taxon: taxonReducer
} );

/* global SERVER_PAYLOAD */
const serverPayload = SERVER_PAYLOAD;

const taxon = new Taxon( serverPayload.taxon );
sharedStore.dispatch( setTaxon( taxon ) );

const renderApp = ( ) => render(
  <Provider store={sharedStore}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);

// Handles loading Google Maps and its libraries, and adds graceful degradation
// if the Maps API is blocked by the browser.
const loadGoogleMaps = ( ) => {
  if (
    typeof ( google ) === "undefined"
    || !google.maps
    || !google.maps.importLibrary
  ) {
    return Promise.resolve( );
  }
  return google.maps.importLibrary( "maps" )
    .then( ( ) => google.maps.importLibrary( "drawing" ) )
    .then( ( ) => google.maps.importLibrary( "geometry" ) )
    .then( ( ) => google.maps.importLibrary( "places" ) )
    .then( ( ) => loadMap3( ) )
    .catch( e => console.warn( "Google Maps failed to load", e ) );
};

loadGoogleMaps( ).then( renderApp );
