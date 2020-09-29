import React from "react";

import Menu from "./menu";
import Profile from "./profile";

const UserSettings = () => (
  <div id="UserSettings">
    <div id="LeftNav">
      <div id="UserSettingsHeader">
        <h2>Settings</h2>
      </div>
      <Menu />
    </div>
    <div className="vl" />
    <Profile />
  </div>
);

export default UserSettings;
