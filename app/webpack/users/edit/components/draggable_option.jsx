import React from "react";
import PropTypes from "prop-types";

const DraggableOption = ( {
  children,
  isDragging,
  onDelete
} ) => (
  <div className={`DraggableOption${isDragging ? " dragging" : ""}`}>
    <div className="move-icons">
      <div>
        <span className="glyphicon glyphicon-triangle-top" />
        <span className="glyphicon glyphicon-triangle-bottom" />
      </div>
    </div>
    <div className="content">
      { children }
    </div>
    <div className="delete-button">
      <button
        type="button"
        className="btn btn-default"
        onClick={onDelete}
      >
        { I18n.t( "delete" ) }
      </button>
    </div>
  </div>
);

DraggableOption.propTypes = {
  children: PropTypes.any,
  isDragging: PropTypes.bool,
  onDelete: PropTypes.func
};

export default DraggableOption;
