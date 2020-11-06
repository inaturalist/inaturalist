import React from "react";
import PropTypes from "prop-types";

const RelationshipsCheckbox = ( {
  name,
  handleCheckboxChange,
  label,
  relationships,
  friendId
} ) => (
  <div className="row">
    <div className="col-xs-12">
      <input
        id={name}
        type="checkbox"
        checked={relationships.filter( u => u.friendUser.id === friendId )[0][name]}
        name={name}
        onChange={e => handleCheckboxChange( e, friendId )}
      />
      <label htmlFor={name} className="margin-left">{label}</label>
    </div>
  </div>
);

RelationshipsCheckbox.propTypes = {
  name: PropTypes.string,
  handleCheckboxChange: PropTypes.func,
  label: PropTypes.string,
  relationships: PropTypes.array,
  friendId: PropTypes.number
};

export default RelationshipsCheckbox;
