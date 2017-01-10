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
import { setDescription } from "../shared/ducks/taxon";
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
if ( taxon.wikipedia_summary ) {
  store.dispatch( setDescription(
    "Wikipedia",
    `https://en.wikipedia.org/wiki/${taxon.wikipedia_title || taxon.name}`,
    taxon.wikipedia_summary
  ) );
} else if ( taxon.auto_summary ) {
  store.dispatch( setDescription(
    $( "meta[property='og:site_name']" ).attr( "content" ),
    null,
    taxon.auto_summary
  ) );
}
store.dispatch( fetchTaxonAssociates( taxon ) );

// Replace state to contain taxon details, so when a user uses the back button
// to get back from future page states we will be able to retrieve the original
// taxon
const s = windowStateForTaxon( taxon );
history.replaceState( s.state, s.title, s.path );

window.onpopstate = e => {
  // User returned from BACK
  if ( e.state && e.state.taxon ) {
    store.dispatch( setTaxon( e.state.taxon ) );
    store.dispatch( fetchTaxon( e.state.taxon ) );
    store.dispatch( fetchTaxonAssociates( e.state.taxon ) );
  }
};

render(
  <Provider store={store}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
