import "babel-polyfill";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, compose, applyMiddleware, combineReducers } from "redux";
import { Taxon } from "inaturalistjs";
import AppContainer from "./containers/app_container";
import configReducer, { setConfig } from "../../shared/ducks/config";
import taxonReducer, { setTaxon, fetchTaxon } from "../shared/ducks/taxon";
import observationsReducer from "./ducks/observations";
import leadersReducer from "./ducks/leaders";
import photoModalReducer from "../shared/ducks/photo_modal";
import { fetchTaxonAssociates } from "./actions/taxon";
import { windowStateForTaxon } from "../shared/util";

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
store.dispatch( fetchTaxonAssociates( taxon ) );

window.onpopstate = e => {
  // User returned from BACK. If the popped state doesn't have a taxon, assume
  // we're back to the intiial page load and use the taxon from the server
  // payload.
  let t = e.state ? e.state.taxon : null;
  t = t || taxon;
  if ( !history.state || !history.state.taxon ) {
    const s = windowStateForTaxon( taxon );
    history.replaceState( s.state, s.title, s.path );
  }
  store.dispatch( setTaxon( t ) );
  store.dispatch( fetchTaxon( t ) );
  store.dispatch( fetchTaxonAssociates( t ) );
};

render(
  <Provider store={store}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
