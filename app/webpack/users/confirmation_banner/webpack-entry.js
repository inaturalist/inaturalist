import React from "react";
import { render } from "react-dom";
import { Provider } from "react-redux";
import BannerContainer from "./containers/banner_container";
import ConfirmationBannerReducer from "../../shared/ducks/user_confirmation";
import confirmModalReducer from "../../observations/show/ducks/confirm_modal";
import sharedStore from "../../shared/shared_store";

const reducers = {
  confirmation: ConfirmationBannerReducer,
  confirmModal: confirmModalReducer
};

sharedStore.injectReducers( reducers );

const element = document.querySelector( "#ConfirmationBanner.dynamic" );
if ( element ) {
  render(
    <Provider store={sharedStore}>
      <BannerContainer />
    </Provider>,
    element
  );
}
