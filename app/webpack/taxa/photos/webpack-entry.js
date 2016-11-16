import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware, combineReducers } from "redux";
import photosReducer, { fetchObservationPhotos } from "./ducks/photos";
import configReducer, { setConfig } from "../../shared/ducks/config";
import taxonReducer, { setTaxon, fetchTaxon } from "../shared/ducks/taxon";
import photoModalReducer from "../shared/ducks/photo_modal";
import App from "./components/app";

const rootReducer = combineReducers( {
  photos: photosReducer,
  config: configReducer,
  taxon: taxonReducer,
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
    preferredPlace: PREFERRED_PLACE,
    chosenPlace: PREFERRED_PLACE
  } ) );
}

if ( TAXON !== undefined && TAXON !== null ) {
  store.dispatch( setTaxon( TAXON ) );
  store.dispatch( fetchTaxon( TAXON ) );
  store.dispatch( fetchObservationPhotos( ) );
}

window.onpopstate = ( ) => {
  // user returned from BACK
};

render(
  <Provider store={store}>
    <App taxon={TAXON} />
  </Provider>,
  document.getElementById( "app" )
);
