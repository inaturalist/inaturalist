import _ from "lodash";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import inatjs, { Taxon } from "inaturalistjs";
import photosReducer, { reloadPhotos, hydrateFromUrlParams } from "./ducks/photos";
import { setConfig } from "../../shared/ducks/config";
import taxonReducer, { setTaxon, fetchTerms } from "../shared/ducks/taxon";
import photoModalReducer from "../shared/ducks/photo_modal";
import AppContainer from "./containers/app_container";
import sharedStore from "../../shared/shared_store";

sharedStore.injectReducers( {
  photos: photosReducer,
  taxon: taxonReducer,
  photoModal: photoModalReducer
} );

if ( PREFERRED_PLACE !== undefined && PREFERRED_PLACE !== null ) {
  // we use this for requesting localized taxon names
  sharedStore.dispatch( setConfig( {
    preferredPlace: PREFERRED_PLACE
  } ) );
}

/* global SERVER_PAYLOAD */
const serverPayload = SERVER_PAYLOAD;
if ( serverPayload.place !== undefined && serverPayload.place !== null ) {
  sharedStore.dispatch( setConfig( {
    chosenPlace: serverPayload.place
  } ) );
}
if ( serverPayload.chosenTab ) {
  sharedStore.dispatch( setConfig( {
    chosenTab: serverPayload.chosenTab
  } ) );
}
if ( serverPayload.ancestorsShown ) {
  sharedStore.dispatch( setConfig( {
    ancestorsShown: serverPayload.ancestorsShown
  } ) );
}

const element = document.querySelector( "meta[name=\"config:inaturalist_api_url\"]" );
const defaultApiUrl = element && element.getAttribute( "content" );
if ( defaultApiUrl ) {
  sharedStore.dispatch( setConfig( {
    testingApiV2: true
  } ) );
  inatjs.setConfig( {
    apiURL: defaultApiUrl.replace( "/v1", "/v2" ),
    writeApiURL: defaultApiUrl.replace( "/v1", "/v2" )
  } );
}

const taxon = new Taxon( serverPayload.taxon );
sharedStore.dispatch( setTaxon( taxon ) );
// fetch taxon terms before rendering the photo browser, in case
// we need to verify a term grouping by termID
sharedStore.dispatch( fetchTerms( ) ).then( ( ) => {
  let urlParams = {};
  if ( window.location.search && window.location.search.length > 0 ) {
    urlParams = $.deparam( window.location.search.replace( /^\?/, "" ) );
  } else if (
    serverPayload.preferred_taxon_photos_query
    && serverPayload.preferred_taxon_photos_query.length > 0
  ) {
    urlParams = $.deparam( serverPayload.preferred_taxon_photos_query );
  }
  if ( !_.isEmpty( urlParams ) ) {
    sharedStore.dispatch( hydrateFromUrlParams( urlParams ) );
  }
  window.onpopstate = e => {
    // user returned from BACK
    sharedStore.dispatch( hydrateFromUrlParams( e.state ) );
    sharedStore.dispatch( reloadPhotos( ) );
  };
  sharedStore.dispatch( reloadPhotos( ) );

  render(
    <Provider store={sharedStore}>
      <AppContainer />
    </Provider>,
    document.getElementById( "app" )
  );
} );
