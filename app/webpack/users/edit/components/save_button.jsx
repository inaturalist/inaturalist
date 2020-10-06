import React from "react";
import { updateUserProfile } from "../ducks/profile";

const SaveButton = ( ) => (
  <div className="save-button">
    <div className="time">
      {I18n.t( "saved_at" )}
      {" time"}
    </div>
    <button
      className="btn btn-xs btn-primary blue-button-caps"
      type="button"
      onClick={updateUserProfile}
    >
      {I18n.t( "save_settings" ).toLocaleUpperCase()}
    </button>
  </div>
);

export default SaveButton;
