import React from "react";
import moment from "moment";
import { render } from "react-dom";
import { Provider } from "react-redux";

import computerVisionDemoReducer from "./ducks/computer_vision_demo";
import ComputerVisionDemo from "./containers/computer_vision_demo";
import sharedStore from "../../shared/shared_store";

moment.locale(I18n.locale);

sharedStore.injectReducers( {
  computerVisionDemo: computerVisionDemoReducer
} );

render(
  <Provider store={sharedStore}>
    <ComputerVisionDemo />
  </Provider>,
  document.getElementById( "app" ));
