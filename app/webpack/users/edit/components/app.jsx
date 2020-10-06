import React from "react";

import Menu from "./menu";
import ProfileContainer from "../containers/profile_container";
import SaveButton from "./save_button";

const App = ( ) => (
  <div className="container">
    <div className="row row-align-center header-margin">
      <div className="col-sm-6">
        <h1>{I18n.t( "settings" )}</h1>
      </div>
      <div className="col-sm-6">
        <SaveButton />
      </div>
    </div>
    <div className="row">
      <div className="col-xs-2 menu">
        <Menu />
      </div>
      <div className="col-xs-1">
        <div className="vl" />
      </div>
      <ProfileContainer />
    </div>
  </div>
);

export default App;
