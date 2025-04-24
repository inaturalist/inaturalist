import React from "react";
import PropTypes from "prop-types";

const SettingsItem = ( {
  header,
  required,
  children,
  htmlFor
} ) => (
  <section className="row settings-item">
    <div className="col-xs-12">
      {( header && htmlFor ) && (
        <h5>
          <label className={required ? "required" : null} htmlFor={htmlFor}>
            {header}
          </label>
        </h5>
      )}
      {children}
    </div>
  </section>
);

SettingsItem.propTypes = {
  header: PropTypes.string,
  required: PropTypes.bool,
  children: PropTypes.any,
  htmlFor: PropTypes.string
};

export default SettingsItem;
