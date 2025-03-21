import React from "react";
import PropTypes from "prop-types";

const CollapseButton = ( { isCollapsed, onToggle, ariaLabel } ) => (
  <button
    type="button"
    className="btn btn-nostyle toggle-collapse"
    onClick={onToggle}
    aria-label={ariaLabel}
    style={{
      position: "absolute",
      top: "0",
      right: "0"
    }}
  >
    <i className={`fa ${isCollapsed ? "fa-chevron-down" : "fa-chevron-up"}`} />
  </button>
);

CollapseButton.propTypes = {
  isCollapsed: PropTypes.bool.isRequired,
  onToggle: PropTypes.func.isRequired,
  ariaLabel: PropTypes.string.isRequired
};

export default CollapseButton;
