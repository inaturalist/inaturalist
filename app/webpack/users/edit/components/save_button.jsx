import React from "react";
import PropTypes from "prop-types";
import moment from "moment";

const SaveButton = ( { saveUserSettings, profile } ) => {
  const handleClick = ( ) => saveUserSettings( );

  console.log( profile, "profile in save button" );

  return (
    <div className="flex-no-wrap space-between-items">
      <div className="text-muted underline">
        {I18n.t( "saved_at" )}
        {` ${moment( profile.updated_at ).format( "h:mm a" )}`}
      </div>
      <button
        className="btn btn-xs btn-primary blue-button-caps"
        type="button"
        onClick={handleClick}
      >
        {I18n.t( "save_settings" ).toLocaleUpperCase()}
      </button>
    </div>
  );
};

SaveButton.propTypes = {
  profile: PropTypes.object,
  saveUserSettings: PropTypes.func
};

export default SaveButton;
