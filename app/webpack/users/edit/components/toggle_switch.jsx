import React from "react";
import PropTypes from "prop-types";

const ToggleSwitch = ( { profile, name, handleCheckboxChange } ) => (
  <div className="col-xs-2 ToggleSwitch">
    <div className="row flex-no-wrap space-between-items">
      <label htmlFor={name}>{I18n.t( "off_toggle" ).toLocaleUpperCase( )}</label>
      <label className="switch">
        <input
          name={name}
          type="checkbox"
          checked={profile[name] || false}
          onChange={handleCheckboxChange}
        />
        <span className="slider round" />
      </label>
      <label htmlFor={name}>{I18n.t( "on_toggle" ).toLocaleUpperCase( )}</label>
    </div>
  </div>
);

ToggleSwitch.propTypes = {
  profile: PropTypes.object,
  name: PropTypes.string,
  handleCheckboxChange: PropTypes.func
};

export default ToggleSwitch;
