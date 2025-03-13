import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";

import reducer from "./reducers";
import SlideshowContainer from "./containers/slideshow_container";
import sharedStore from "../shared/shared_store";

sharedStore.injectReducers( {
  slideshow: reducer
} );

render(
  <Provider store={sharedStore}>
    <SlideshowContainer />
  </Provider>,
  document.getElementById( "app" )
);
