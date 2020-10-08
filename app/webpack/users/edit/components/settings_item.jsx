import React from "react";
import PropTypes from "prop-types";

const SettingsItem = ( { children, header, required } ) => (
  <div className="profile-setting">
    <h5>
      {I18n.t( header )}
      {required && <div className="asterisk">*</div>}
    </h5>
    {children}
  </div>
);

SettingsItem.propTypes = {
  children: PropTypes.any,
  header: PropTypes.string,
  required: PropTypes.bool
};

export default SettingsItem;
