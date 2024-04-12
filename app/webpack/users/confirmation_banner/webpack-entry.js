import _ from "lodash";
import "core-js/stable";
import "regenerator-runtime/runtime";
import thunkMiddleware from "redux-thunk";
import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import {
  createStore, compose, applyMiddleware, combineReducers
} from "redux";
import BannerContainer from "./containers/banner_container";
import ConfirmationBannerReducer from "./reducers/reducer";
import configReducer, { setConfig, updateConfig } from "../../shared/ducks/config";
import confirmModalReducer from "../../observations/show/ducks/confirm_modal";

const rootReducer = combineReducers( {
  config: configReducer,
  confirmation: ConfirmationBannerReducer,
  confirmModal: confirmModalReducer
} );

const store = createStore(
  rootReducer,
  compose(
    applyMiddleware( thunkMiddleware ),
    // enable Redux DevTools if available
    window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
  )
);

if ( !_.isEmpty( CONFIG ) ) {
  store.dispatch( setConfig( CONFIG ) );
}

if ( !_.isEmpty( CURRENT_USER ) ) {
  store.dispatch( updateConfig( {
    currentUser: CURRENT_USER
  } ) );
}

const element = document.getElementById( "ConfirmationBanner" );
if ( element ) {
  render(
    <Provider store={store}>
      <BannerContainer />
    </Provider>,
    element
  );
}
