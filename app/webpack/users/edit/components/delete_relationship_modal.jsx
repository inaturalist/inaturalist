import React from "react";
import PropTypes from "prop-types";
import { Modal, Button } from "react-bootstrap";

import ModalCloseButton from "./modal_close_button";

const DeleteRelationshipModal = ( {
  show,
  onClose,
  deleteRelationship,
  user
} ) => (
  <Modal
    show={show}
    className="RevokeAccessModal"
    onHide={onClose}
  >
    <Modal.Body>
      <h4>{I18n.t( "remove_relationship_question" )}</h4>
      <ModalCloseButton onClose={onClose} />
      <p>{I18n.t( "you_will_no_longer_be_following_or_trusting", { user } )}</p>
    </Modal.Body>
    <Modal.Footer>
      <div className="buttons">
        <Button bsStyle="primary" onClick={deleteRelationship}>
          {I18n.t( "remove_relationship_caps" )}
        </Button>
      </div>
    </Modal.Footer>
  </Modal>
);

DeleteRelationshipModal.propTypes = {
  show: PropTypes.bool,
  onClose: PropTypes.func,
  deleteRelationship: PropTypes.func,
  user: PropTypes.string
};

export default DeleteRelationshipModal;
