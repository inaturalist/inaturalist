import React from "react";
import PropTypes from "prop-types";

const RelationshipsCheckbox = ( {
  name,
  handleCheckboxChange,
  label,
  relationships,
  id
} ) => {
  const inputID = `RelationshipsCheckbox-${name}-${id}`;
  return (
    <div>
      <input
        id={inputID}
        type="checkbox"
        checked={relationships.filter( u => u.id === id )[0][name]}
        name={name}
        onChange={e => handleCheckboxChange( e, id )}
      />
      <label htmlFor={inputID} className="checkbox-label">{label}</label>
    </div>
  );
};

RelationshipsCheckbox.propTypes = {
  name: PropTypes.string,
  handleCheckboxChange: PropTypes.func,
  label: PropTypes.string,
  relationships: PropTypes.array,
  id: PropTypes.number
};

export default RelationshipsCheckbox;
