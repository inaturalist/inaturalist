import "core-js/stable";
import "regenerator-runtime/runtime";
import _ from "lodash";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import {
  applyMiddleware,
  combineReducers,
  compose,
  createStore
} from "redux";
import { Taxon } from "inaturalistjs";
import photosReducer, { reloadPhotos, hydrateFromUrlParams } from "./ducks/photos";
import configReducer, { setConfig } from "../../shared/ducks/config";
import taxonReducer, { setTaxon, fetchTerms } from "../shared/ducks/taxon";
import photoModalReducer from "../shared/ducks/photo_modal";
import AppContainer from "./containers/app_container";

const rootReducer = combineReducers( {
  photos: photosReducer,
  config: configReducer,
  taxon: taxonReducer,
  photoModal: photoModalReducer
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

if ( PREFERRED_PLACE !== undefined && PREFERRED_PLACE !== null ) {
  // we use this for requesting localized taxon names
  store.dispatch( setConfig( {
    preferredPlace: PREFERRED_PLACE
  } ) );
}

/* global SERVER_PAYLOAD */
const serverPayload = SERVER_PAYLOAD;
if ( serverPayload.place !== undefined && serverPayload.place !== null ) {
  store.dispatch( setConfig( {
    chosenPlace: serverPayload.place
  } ) );
}
if ( serverPayload.chosenTab ) {
  store.dispatch( setConfig( {
    chosenTab: serverPayload.chosenTab
  } ) );
}
if ( serverPayload.ancestorsShown ) {
  store.dispatch( setConfig( {
    ancestorsShown: serverPayload.ancestorsShown
  } ) );
}
const taxon = new Taxon( serverPayload.taxon );
store.dispatch( setTaxon( taxon ) );
// fetch taxon terms before rendering the photo browser, in case
// we need to verify a term grouping by termID
store.dispatch( fetchTerms( ) ).then( ( ) => {
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
    store.dispatch( hydrateFromUrlParams( urlParams ) );
  }
  window.onpopstate = e => {
    // user returned from BACK
    store.dispatch( hydrateFromUrlParams( e.state ) );
    store.dispatch( reloadPhotos( ) );
  };
  store.dispatch( reloadPhotos( ) );

  render(
    <Provider store={store}>
      <AppContainer />
    </Provider>,
    document.getElementById( "app" )
  );
} );
