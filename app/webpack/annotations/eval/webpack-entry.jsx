import React from "react";
import moment from "moment";
import { render } from "react-dom";
import { Provider } from "react-redux";

import annotationEvalReducer, { lookupObservation } from "./ducks/annotation_eval";
import AnnotationEvalContainer from "./containers/annotation_eval_container";
import sharedStore from "../../shared/shared_store";

moment.locale( I18n.locale );

sharedStore.injectReducers( {
  annotationEval: annotationEvalReducer
} );

const getParams = $.deparam( window.location.search.replace( /^\?/, "" ) );
if ( getParams.observation_id ) {
  sharedStore.dispatch( lookupObservation( getParams.observation_id ) );
}

render(
  <Provider store={sharedStore}>
    <AnnotationEvalContainer />
  </Provider>,
  document.getElementById( "app" )
);
