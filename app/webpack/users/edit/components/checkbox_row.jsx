import React from "react";
import PropTypes from "prop-types";

const CheckboxRow = ( {
  profile,
  name,
  handleCheckboxChange,
  label,
  description,
  disabled
} ) => (
  <div className="row">
    <div className="col-xs-12">
      <input
        id={`user_${name}`}
        type="checkbox"
        // false when profile[name] is undefined
        checked={profile[name] || false}
        name={name}
        onChange={handleCheckboxChange}
        disabled={disabled}
      />
      <label htmlFor={`user_${name}`} className="checkbox-label">{label}</label>
      <div className="checkbox-description-margin">
        {description}
      </div>
    </div>
  </div>
);

CheckboxRow.propTypes = {
  profile: PropTypes.object,
  name: PropTypes.string,
  handleCheckboxChange: PropTypes.func,
  label: PropTypes.string,
  description: PropTypes.object,
  disabled: PropTypes.bool
};

export default CheckboxRow;
