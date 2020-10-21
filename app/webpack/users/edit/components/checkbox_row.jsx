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
    <div className="col-xs-12">
      <input
        id={`user_${name}`}
        type="checkbox"
        // false when profile[name] is undefined
        checked={profile[name] || false}
        name={name}
        onChange={handleCheckboxChange}
      />
      <label htmlFor={`user_${name}`} className="margin-left">{label}</label>
      <div className="description-margin-left">
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
  description: PropTypes.object
};

export default CheckboxRow;
