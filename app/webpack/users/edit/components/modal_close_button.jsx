import React from "react";
import PropTypes from "prop-types";

const ModalCloseButton = ( { onClose } ) => (
  <button
    type="button"
    className="btn btn-nostyle"
    onClick={onClose}
  >
    <i className="fa fa-times text-muted hide-button fa-2x" aria-hidden="true" />
  </button>
);

ModalCloseButton.propTypes = {
  onClose: PropTypes.func
};

export default ModalCloseButton;
