import React from "react";
import PropTypes from "prop-types";

const ToggleSwitch = ( { checked, name, handleCheckboxChange } ) => (
  <div className="col-xs-4 col-md-3 ToggleSwitch">
    <div className="flex-no-wrap">
      <label htmlFor={name}>{I18n.t( "off_caps" )}</label>
      <label className="switch">
        <input
          name={name}
          type="checkbox"
          checked={checked || false}
          onChange={handleCheckboxChange}
        />
        <span className="slider round" />
      </label>
      <label htmlFor={name}>{I18n.t( "on_caps" )}</label>
    </div>
  </div>
);

ToggleSwitch.propTypes = {
  checked: PropTypes.bool,
  name: PropTypes.string,
  handleCheckboxChange: PropTypes.func
};

export default ToggleSwitch;
