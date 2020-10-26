import React from "react";
import PropTypes from "prop-types";
import { Modal, Button } from "react-bootstrap";

const RevokeAccessModal = ( { show, onClose } ) => (
  <Modal
    show={show}
    className="RevokeAccessModal"
    onHide={onClose}
  >
    <Modal.Body>
      <h4>{I18n.t( "log_out_of_application", { site_name: "Seek" } ) || I18n.t( "revoke_external_application", { site_name: "Seek" } )}</h4>
      <button
        type="button"
        className="btn btn-nostyle"
        onClick={onClose}
      >
        <i className="fa fa-times text-muted hide-button fa-2x" aria-hidden="true" />
      </button>
      <p>{I18n.t( "this_will_sign_you_out_current_session" )}</p>
    </Modal.Body>
    <Modal.Footer>
      <div className="buttons">
        <Button bsStyle="primary" onClick={onClose}>
          {I18n.t( "log_out" ).toLocaleUpperCase( ) || I18n.t( "revoke" ).toLocaleUpperCase( )}
        </Button>
      </div>
    </Modal.Footer>
  </Modal>
);

RevokeAccessModal.propTypes = {
  show: PropTypes.bool,
  // message: PropTypes.any,
  // onCancel: PropTypes.func,
  onClose: PropTypes.func
  // onConfirm: PropTypes.func,
  // cancelText: PropTypes.string,
  // confirmText: PropTypes.string,
  // confirmClass: PropTypes.string,
  // updateState: PropTypes.func,
  // hideCancel: PropTypes.bool,
  // title: PropTypes.string
};

export default RevokeAccessModal;
