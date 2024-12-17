import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import utf8 from "utf8";
import compareReducer, { fetchDataForTab, setAttributes } from "./ducks/compare";
import taxonChildrenReducer from "./ducks/taxon_children_modal";
import App from "./components/app";
import sharedStore from "../../shared/shared_store";

sharedStore.injectReducers( {
  compare: compareReducer,
  taxonChildrenModal: taxonChildrenReducer
} );

const urlParams = $.deparam( window.location.search.replace( /^\?/, "" ) );
if ( urlParams && urlParams.s ) {
  const encoded = atob( urlParams.s );
  const json = utf8.decode( encoded );
  sharedStore.dispatch( setAttributes( JSON.parse( json ) ) );
}

sharedStore.dispatch( fetchDataForTab( ) );

render(
  <Provider store={sharedStore}>
    <App />
  </Provider>,
  document.getElementById( "app" )
);
