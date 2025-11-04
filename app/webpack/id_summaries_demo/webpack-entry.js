// app/webpack/entry/id_summaries_demo.js (or your current entry file)

import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import { createStore, applyMiddleware, compose } from "redux";
import thunk from "redux-thunk";
import inatjs from "inaturalistjs";

// <-- import your combined reducers (from the actions/reducers setup we added)
import reducers from "../id_summaries_demo/reducers";

// Your existing app component
import IdSummariesDemoApp from "../id_summaries_demo/id_summaries_demo_app.jsx";

const element = document.querySelector( "meta[name=\"config:inaturalist_api_url\"]" );
const defaultApiUrl = element && element.getAttribute( "content" );
if ( defaultApiUrl ) {
  inatjs.setConfig( {
    apiURL: defaultApiUrl.replace( "/v1", "/v2" ),
    writeApiURL: defaultApiUrl.replace( "/v1", "/v2" )
  } );
}

// Enable Redux DevTools if available, otherwise fall back to compose
const composeEnhancers =
  (typeof window !== "undefined" && window.__REDUX_DEVTOOLS_EXTENSION_COMPOSE__) || compose;

// Create the store inline with thunk
const store = createStore(reducers, composeEnhancers(applyMiddleware(thunk)));

render(
  <Provider store={store}>
    <IdSummariesDemoApp />
  </Provider>,
  document.getElementById("app")
);
