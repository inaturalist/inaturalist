import _ from "lodash";
import "core-js/stable";
import "regenerator-runtime/runtime";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import {
  createStore,
  compose,
  applyMiddleware,
  combineReducers
} from "redux";
import utf8 from "utf8";
import configReducer from "../../shared/ducks/config";
import compareReducer, { DEFAULT_STATE, fetchDataForTab } from "./ducks/compare";
import taxonChildrenReducer from "./ducks/taxon_children_modal";
import App from "./components/app";

const rootReducer = combineReducers( {
  compare: compareReducer,
  taxonChildrenModal: taxonChildrenReducer,
  config: configReducer
} );

const urlParams = $.deparam( window.location.search.replace( /^\?/, "" ) );
let initialState;
if ( urlParams && urlParams.s ) {
  const encoded = atob( urlParams.s );
  const json = utf8.decode( encoded );
  initialState = Object.assign( {}, DEFAULT_STATE, JSON.parse( json ) );
}

const store = createStore(
  rootReducer,
  {
    compare: initialState
  },
  compose( ..._.compact( [
    applyMiddleware( thunkMiddleware ),
    // enable Redux DevTools if available
    window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
  ] ) )
);

store.dispatch( fetchDataForTab( ) );

render(
  <Provider store={store}>
    <App />
  </Provider>,
  document.getElementById( "app" )
);
