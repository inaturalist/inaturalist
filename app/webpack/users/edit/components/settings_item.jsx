import React from "react";
import PropTypes from "prop-types";

const SettingsItem = ( { header, required, children } ) => (
  <div className="settings-item">
    <h5>
      {header}
      {required && <div className="asterisk">*</div>}
    </h5>
    {children}
  </div>
);

SettingsItem.propTypes = {
  header: PropTypes.string,
  required: PropTypes.bool,
  children: PropTypes.any
};

export default SettingsItem;
