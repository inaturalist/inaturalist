import React from "react";

import Menu from "./menu";
import Profile from "./profile";
import SaveButton from "./save_button";

const App = () => (
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
      <Profile />
    </div>
  </div>
);

export default App;
