import React from "react";
import PropTypes from "prop-types";
import moment from "moment";

const SaveButton = ( { saveUserSettings, profile } ) => {
  const disabled = profile.saved_status === null || profile.saved_status === "saved";

  return (
    <div className="flex-no-wrap save-button">
      <div className={profile.saved_status === "saved" ? "text-muted saved-time" : "collapse"}>
        { I18n.t( "saved_at_time", {
          time: moment( profile.updated_at ).format( I18n.t( "momentjs.time_hours" ) )
        } ) }
      </div>
      <button
        className={`btn btn-inat ${disabled ? "btn-default" : "btn-primary"}`}
        disabled={disabled}
        type="button"
        onClick={saveUserSettings}
      >
        <div className="btn-save-text">{I18n.t( "save_settings_caps" )}</div>
      </button>
    </div>
  );
};

SaveButton.propTypes = {
  profile: PropTypes.object,
  saveUserSettings: PropTypes.func
};

export default SaveButton;
