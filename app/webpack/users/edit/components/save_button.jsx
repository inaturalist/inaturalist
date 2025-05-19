import React from "react";
import PropTypes from "prop-types";
import moment from "moment";

const SaveButton = ( { saveUserSettings, userSettings } ) => {
  const disabled = userSettings.saved_status === null || userSettings.saved_status === "saved";

  return (
    <div className="flex-no-wrap save-button">
      <div className={userSettings.saved_status === "saved" ? "text-muted saved-time status" : "collapse"}>
        { I18n.t( "saved_at_time", {
          time: moment( userSettings.updated_at ).format( I18n.t( "momentjs.time_hours" ) )
        } ) }
      </div>
      <div className={userSettings.errors ? "text-danger status" : "collapse"}>
        { I18n.t( "doh_something_went_wrong" ) }
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
  saveUserSettings: PropTypes.func,
  userSettings: PropTypes.object
};

export default SaveButton;
