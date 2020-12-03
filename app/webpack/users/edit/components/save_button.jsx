import React from "react";
import PropTypes from "prop-types";
import moment from "moment";

const SaveButton = ( { saveUserSettings, profile } ) => (
  <div className="flex-no-wrap flex-start-xs flex-end">
    <div className={profile.saved_status === "saved" ? "text-muted underline margin-right-medium" : "collapse"}>
      {I18n.t( "saved_at_time", { time: moment( profile.updated_at ).format( "h:mm a" ) } )}
    </div>
    <button
      className={`btn btn-inat ${profile.saved_status === null ? "btn-default" : "btn-primary"}`}
      disabled={profile.saved_status === null}
      type="button"
      onClick={saveUserSettings}
    >
      <div className="btn-save-text">{I18n.t( "save_settings_caps" )}</div>
    </button>
  </div>
);

SaveButton.propTypes = {
  profile: PropTypes.object,
  saveUserSettings: PropTypes.func
};

export default SaveButton;
