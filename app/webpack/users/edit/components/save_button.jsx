import React from "react";
import PropTypes from "prop-types";

const SaveButton = ( { saveUserProfile } ) => {
  const handleClick = ( ) => saveUserProfile( );

  return (
    <div className="save-button">
      <div className="time">
        {I18n.t( "saved_at" )}
        {" time"}
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
  saveUserProfile: PropTypes.func
};

export default SaveButton;
