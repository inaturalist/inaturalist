import React from "react";
import PropTypes from "prop-types";

import Menu from "./menu";
import Profile from "./profile";
import SaveButton from "./save_button";

const App = ( { config } ) => (
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
      <Profile config={config} />
    </div>
  </div>
);

App.propTypes = {
  config: PropTypes.object
};

export default App;
