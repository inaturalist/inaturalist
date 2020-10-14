import React from "react";
import PropTypes from "prop-types";

const CheckboxRow = ( {
  profile,
  name,
  handleCheckboxChange,
  label,
  description
} ) => (
  <div className="row">
    <div className="col-xs-1">
      <input
        type="checkbox"
        className="form-check-input"
        checked={profile[name]}
        value={profile[name]}
        name={name}
        onChange={handleCheckboxChange}
      />
    </div>
    <div className="col-xs-10">
      <label>{label}</label>
      {description}
    </div>
  </div>
);

CheckboxRow.propTypes = {
  profile: PropTypes.object,
  name: PropTypes.string,
  handleCheckboxChange: PropTypes.func,
  label: PropTypes.string,
  description: PropTypes.object
};

export default CheckboxRow;
