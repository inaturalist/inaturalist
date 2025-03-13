import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import _ from "lodash";
import moment from "moment";

import reducers from "./reducers";
import Uploader from "./containers/uploader";
import { fetchSavedLocations } from "./ducks/saved_locations";
import sharedStore from "../../shared/shared_store";

moment.locale( I18n.locale );

sharedStore.injectReducers( reducers );

if ( !_.isEmpty( CURRENT_USER ) ) {
  sharedStore.dispatch( fetchSavedLocations( ) );
}

render(
  <Provider store={sharedStore}>
    <Uploader />
  </Provider>,
  document.getElementById( "app" )
);
