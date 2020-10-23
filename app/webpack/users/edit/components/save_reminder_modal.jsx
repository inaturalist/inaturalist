import React from "react";
import PropTypes from "prop-types";

import { Modal } from "react-bootstrap";

const SaveReminderModal = ( { showModal } ) => (
  <Modal
    show={showModal}
    onHide={( ) => console.log( "hide" )}
    bsSize="large"
    className="PhotoModal"
  >
    <div>save content</div>
  </Modal>
);

SaveReminderModal.propTypes = {
  showModal: PropTypes.bool
};

export default SaveReminderModal;
