import React from "react";
import PropTypes from "prop-types";
import { Modal, Button } from "react-bootstrap";

const RevokeAccessModal = ( {
  show,
  onClose,
  deleteApp,
  siteName,
  official
} ) => (
  <Modal
    show={show}
    className="RevokeAccessModal"
    onHide={onClose}
  >
    <Modal.Header closeButton>
      <Modal.Title>
        {official
          ? I18n.t( "log_out_of_application", { site_name: siteName } )
          : I18n.t( "revoke_external_application", { site_name: siteName } )}
      </Modal.Title>
    </Modal.Header>
    <Modal.Body>
      <p>{I18n.t( "this_will_sign_you_out_current_session" )}</p>
    </Modal.Body>
    <Modal.Footer>
      <div className="buttons">
        <Button bsStyle="primary" onClick={deleteApp}>
          {official ? I18n.t( "log_out_caps" ) : I18n.t( "revoke_caps" )}
        </Button>
      </div>
    </Modal.Footer>
  </Modal>
);

RevokeAccessModal.propTypes = {
  show: PropTypes.bool,
  onClose: PropTypes.func,
  deleteApp: PropTypes.func,
  siteName: PropTypes.string,
  official: PropTypes.bool
};

export default RevokeAccessModal;
