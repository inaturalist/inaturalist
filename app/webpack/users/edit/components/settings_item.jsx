import React from "react";
import PropTypes from "prop-types";

const SettingsItem = ( {
  header,
  required,
  children,
  htmlFor
} ) => (
  <div className="row settings-item">
    <div className="col-xs-12">
      {( header && htmlFor ) && (
        <label className={required ? "required" : null} htmlFor={htmlFor}>
          {header}
        </label>
      )}
      {children}
    </div>
  </div>
);

SettingsItem.propTypes = {
  header: PropTypes.string,
  required: PropTypes.bool,
  children: PropTypes.any,
  htmlFor: PropTypes.string
};

export default SettingsItem;
