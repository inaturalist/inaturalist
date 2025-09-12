import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import inatjs from "inaturalistjs";
import AppContainer from "./containers/app_container";
import { setConfig } from "../../shared/ducks/config";
import taxonReducer, { setTaxon, fetchTaxon, setDescription } from "../shared/ducks/taxon";
import observationsReducer from "./ducks/observations";
import leadersReducer from "./ducks/leaders";
import photoModalReducer from "../shared/ducks/photo_modal";
import { fetchTaxonAssociates } from "./actions/taxon";
import { windowStateForTaxon, tabFromLocationHash } from "../shared/util";
import sharedStore from "../../shared/shared_store";

const { Taxon } = inatjs;

sharedStore.injectReducers( {
  taxon: taxonReducer,
  observations: observationsReducer,
  leaders: leadersReducer,
  photoModal: photoModalReducer
} );

if ( PREFERRED_PLACE !== undefined && PREFERRED_PLACE !== null ) {
  // we use this for requesting localized taxon names
  sharedStore.dispatch( setConfig( {
    preferredPlace: PREFERRED_PLACE
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

/* global SERVER_PAYLOAD */
const serverPayload = SERVER_PAYLOAD;
if ( serverPayload.place !== undefined && serverPayload.place !== null ) {
  sharedStore.dispatch( setConfig( {
    chosenPlace: serverPayload.place
  } ) );
}
sharedStore.dispatch( setConfig( {
  chosenTab: tabFromLocationHash( serverPayload.taxon.rank_level )?.tab || serverPayload.chosenTab || "articles"
} ) );
if ( serverPayload.ancestorsShown ) {
  sharedStore.dispatch( setConfig( {
    ancestorsShown: serverPayload.ancestorsShown
  } ) );
}

const taxon = new Taxon( serverPayload.taxon );
sharedStore.dispatch( setTaxon( taxon ) );
if ( taxon.wikipedia_summary ) {
  sharedStore.dispatch( setDescription(
    "Wikipedia",
    `https://en.wikipedia.org/wiki/${taxon.wikipedia_title || taxon.name}`,
    taxon.wikipedia_summary
  ) );
} else if ( taxon.auto_summary ) {
  sharedStore.dispatch( setDescription(
    $( "meta[property='og:site_name']" ).attr( "content" ),
    null,
    taxon.auto_summary
  ) );
}
sharedStore.dispatch( fetchTaxonAssociates( taxon ) );

// Replace state to contain taxon details, so when a user uses the back button
// to get back from future page states we will be able to retrieve the original
// taxon
const s = windowStateForTaxon( taxon );
history.replaceState( s.state, s.title, s.url );

window.onpopstate = e => {
  // User returned from BACK
  if ( e.state && e.state.taxon ) {
    sharedStore.dispatch( setTaxon( new Taxon( e.state.taxon ) ) );
    sharedStore.dispatch( fetchTaxon( e.state.taxon ) );
    sharedStore.dispatch( fetchTaxonAssociates( e.state.taxon ) );
  }
};

render(
  <Provider store={sharedStore}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
