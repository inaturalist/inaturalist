import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import AppContainer from "./containers/app_container";
import { setConfig } from "../../shared/ducks/config";
import geoModelReducer, { fetchTaxa } from "./ducks/geo_model";
import sharedStore from "../../shared/shared_store";

sharedStore.injectReducers( {
  geo_model_taxa: geoModelReducer
} );

sharedStore.dispatch( setConfig( {
  orderBy: "name",
  order: "asc"
} ) );

sharedStore.dispatch( fetchTaxa( ) );

render(
  <Provider store={sharedStore}>
    <AppContainer />
  </Provider>,
  document.getElementById( "app" )
);
