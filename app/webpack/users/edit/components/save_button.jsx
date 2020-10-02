import React from "react";

const SaveButton = () => (
  <div id="Row" className="center">
    <div id="Time" className="time-margin">
      {I18n.t( "saved_at" )}
      {" time"}
    </div>
    <button className="blue-button-caps" type="button">
      <div className="blue-button-text-caps">
        {I18n.t( "save_settings" ).toLocaleUpperCase()}
      </div>
    </button>
  </div>
);

export default SaveButton;
