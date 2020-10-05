import React from "react";

import Menu from "./menu";
import ProfileContainer from "../containers/profile_container";
import SaveButton from "./save_button";

const App = ( ) => (
  <div>
    <div className="container-fluid">
      container text
      <div className="row">
        <div className="col-xs-2">
        text
        </div>
        <div className="col-xs-10">
          profile, not sidebar
          <button className="btn btn-xs btn-inat btn-primary" type="button">button</button>
          <div className="input-group">
            <input type="text" className="form-control" />
          </div>
        </div>
      </div>
    </div>
    <div id="Column" className="left-nav">
      <div id="Row" className="settings-row">
        <div id="UserSettingsHeader">
          <h2>{I18n.t( "settings" )}</h2>
        </div>
        <SaveButton />
      </div>
      <div id="Row">
        <Menu />
        <div className="vl" />
        <ProfileContainer />
      </div>
    </div>
  </div>
);

export default App;
