import React from "react";
import moment from "moment";
import { render } from "react-dom";
import { Provider } from "react-redux";

import computerVisionEvalReducer, { fetchAndEvalObservation } from "./ducks/computer_vision_eval";
import ComputerVisionEvalContainer from "./containers/computer_vision_eval_container";
import sharedStore from "../../shared/shared_store";

moment.locale( I18n.locale );

sharedStore.injectReducers( {
  computerVisionEval: computerVisionEvalReducer
} );

const getParams = $.deparam( window.location.search.replace( /^\?/, "" ) );
if ( getParams.observation_id ) {
  sharedStore.dispatch( fetchAndEvalObservation( getParams.observation_id ) );
}

render(
  <Provider store={sharedStore}>
    <ComputerVisionEvalContainer />
  </Provider>,
  document.getElementById( "app" )
);
