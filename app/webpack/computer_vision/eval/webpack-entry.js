import _ from "lodash";
import "core-js/stable";
import "regenerator-runtime/runtime";
import thunkMiddleware from "redux-thunk";
import {
  applyMiddleware,
  combineReducers,
  compose,
  createStore
} from "redux";
import React from "react";
import moment from "moment";
import { render } from "react-dom";
import { Provider } from "react-redux";

import computerVisionEvalReducer, { fetchAndEvalObservation } from "./ducks/computer_vision_eval";
import ComputerVisionEvalContainer from "./containers/computer_vision_eval_container";
import configReducer, { setConfig } from "../../shared/ducks/config";

moment.locale( I18n.locale );

const rootReducer = combineReducers( {
  computerVisionEval: computerVisionEvalReducer,
  config: configReducer
} );

const store = createStore(
  rootReducer,
  compose( ..._.compact( [
    applyMiddleware( thunkMiddleware ),
    // enable Redux DevTools if available
    window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
  ] ) )
);

if ( !_.isEmpty( CURRENT_USER ) ) {
  store.dispatch( setConfig( { currentUser: CURRENT_USER } ) );
}

const getParams = $.deparam( window.location.search.replace( /^\?/, "" ) );
if ( getParams.observation_id ) {
  store.dispatch( fetchAndEvalObservation( getParams.observation_id ) );
}

render(
  <Provider store={store}>
    <ComputerVisionEvalContainer />
  </Provider>,
  document.getElementById( "app" )
);
