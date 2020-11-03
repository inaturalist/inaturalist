import React from "react";
import PropTypes from "prop-types";
import { Modal, Button } from "react-bootstrap";

import ModalCloseButton from "./modal_close_button";

const iNatAppIds = [2, 3, 315, 333];

const RevokeAccessModal = ( {
  show,
  onClose,
  deleteApp,
  id
} ) => (
  <Modal
    show={show}
    className="RevokeAccessModal"
    onHide={onClose}
  >
    <Modal.Body>
      <h4>
        {iNatAppIds.includes( id )
          ? I18n.t( "log_out_of_application", { site_name: "Seek" } )
          : I18n.t( "revoke_external_application", { site_name: "Seek" } )}
      </h4>
      <ModalCloseButton onClose={onClose} />
      <p>{I18n.t( "this_will_sign_you_out_current_session" )}</p>
    </Modal.Body>
    <Modal.Footer>
      <div className="buttons">
        <Button bsStyle="primary" onClick={deleteApp}>
          {iNatAppIds.includes( id )
            ? I18n.t( "log_out" ).toLocaleUpperCase( )
            : I18n.t( "revoke" ).toLocaleUpperCase( )}
        </Button>
      </div>
    </Modal.Footer>
  </Modal>
);

RevokeAccessModal.propTypes = {
  show: PropTypes.bool,
  onClose: PropTypes.func,
  deleteApp: PropTypes.func,
  id: PropTypes.number
};

export default RevokeAccessModal;
