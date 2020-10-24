import React from "react";
import PropTypes from "prop-types";
import { Modal, Button } from "react-bootstrap";

const RevokeAccessModal = ( { showModal, title } ) => (
  <Modal
    show={showModal}
    className="RevokeAccessModal"
    onHide={( ) => console.log( "on hide clicked" )}
  >
    <Modal.Body>
      <h4>{I18n.t( "log_out_of_application", { site_name: "Seek" } ) || I18n.t( "revoke_external_application", { site_name: "Seek" } )}</h4>
      <i className="fa fa-times text-muted hide-button fa-2x" aria-hidden="true" onClick={( ) => "hide modal"} />
      <p>{I18n.t( "this_will_sign_you_out_current_session" )}</p>
    </Modal.Body>
    <Modal.Footer>
      <div className="buttons">
        <Button bsStyle="primary" onClick={( ) => console.log( "use revoke link on click" )}>
          {I18n.t( "log_out" ).toLocaleUpperCase( ) || I18n.t( "revoke" ).toLocaleUpperCase( )}
        </Button>
      </div>
    </Modal.Footer>
  </Modal>
);

RevokeAccessModal.propTypes = {
  showModal: PropTypes.bool,
  // message: PropTypes.any,
  // onCancel: PropTypes.func,
  // onClose: PropTypes.func,
  // onConfirm: PropTypes.func,
  // cancelText: PropTypes.string,
  // confirmText: PropTypes.string,
  // confirmClass: PropTypes.string,
  // updateState: PropTypes.func,
  // hideCancel: PropTypes.bool,
  title: PropTypes.string
};

export default RevokeAccessModal;
