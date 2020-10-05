import React from "react";

const SaveButton = () => (
  <div id="Row" className="center">
    <div id="Time" className="time-margin">
      {I18n.t( "saved_at" )}
      {" time"}
    </div>
    <button className="btn btn-xs btn-primary blue-button-caps" type="button">
      {I18n.t( "save_settings" ).toLocaleUpperCase()}
    </button>
  </div>
);

export default SaveButton;
