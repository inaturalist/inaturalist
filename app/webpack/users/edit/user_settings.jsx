import React from "react";

import Menu from "./menu";
import Profile from "./profile";

const UserSettings = () => (
  <div id="UserSettings">
    <div id="Column">
      <div id="UserSettingsHeader">
        <h2>{I18n.t( "settings" )}</h2>
      </div>
      <Menu />
    </div>
    <div className="vl" />
    <Profile />
  </div>
);

export default UserSettings;
