import React from "react";
import PropTypes from "prop-types";

const SettingsItem = ( { header, required, children } ) => (
  <div className="row settings-item">
    <div className="col-xs-12">
      <h4>
        {header}
        {required && " *"}
      </h4>
      {children}
    </div>
  </div>
);

SettingsItem.propTypes = {
  header: PropTypes.string,
  required: PropTypes.bool,
  children: PropTypes.any
};

export default SettingsItem;
