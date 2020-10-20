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
      {profile[name] !== undefined && (
        <input
          id={`user_${name}`}
          type="checkbox"
          className="form-check-input"
          checked={profile[name]}
          name={name}
          onChange={handleCheckboxChange}
        />
      )}
    </div>
    <div className="col-xs-10">
      <label htmlFor={`user_${name}`}>{label}</label>
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
