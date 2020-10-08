import React from "react";

import Menu from "./menu";
import ProfileContainer from "../containers/profile_container";
import SaveButtonContainer from "../containers/save_button_container";
import Account from "./account";

const App = ( ) => (
  <div className="container">
    <div className="row row-align-center header-margin">
      <div className="col-sm-9">
        <h1>{I18n.t( "settings" )}</h1>
      </div>
      <div className="col-sm-3">
        <SaveButtonContainer />
      </div>
    </div>
    <div className="row">
      <div className="col-xs-2 menu">
        <Menu />
      </div>
      <div className="col-xs-1">
        <div className="vl" />
      </div>
      <Account />
      {/* <ProfileContainer /> */}
    </div>
  </div>
);

export default App;
