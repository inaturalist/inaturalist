import React from "react";
import PropTypes from "prop-types";
import {
  Modal,
  Button
} from "react-bootstrap";

const AlertModal = ( {
  visible,
  title,
  content,
  onConfirm,
  onClose,
  onCancel
} ) => {
  let modalFooter = (
    <Modal.Footer>
      <Button onClick={onClose} bsStyle="primary">{ I18n.t( "ok" ) }</Button>
    </Modal.Footer>
  );
  if ( onConfirm ) {
    modalFooter = (
      <Modal.Footer>
        <Button
          onClick={( ) => {
            onClose( );
            if ( onCancel ) {
              onCancel( );
            }
          }}
        >
          { I18n.t( "cancel" ) }
        </Button>
        <Button
          bsStyle="primary"
          onClick={( ) => {
            onConfirm( );
            onClose( );
          }}
        >
          { I18n.t( "ok" ) }
        </Button>
      </Modal.Footer>
    );
  }
  return (
    <Modal
      show={visible}
      className="AlertModal"
      bsSize="small"
      backdrop={false}
      onHide={onClose}
    >
      <Modal.Header closeButton>
        <Modal.Title>
          { title || I18n.t( "alert" ) }
        </Modal.Title>
      </Modal.Header>
      <Modal.Body>
        { content }
      </Modal.Body>
      { modalFooter }
    </Modal>
  );
};

AlertModal.propTypes = {
  visible: PropTypes.bool,
  title: PropTypes.string,
  content: PropTypes.string,
  onConfirm: PropTypes.func,
  onClose: PropTypes.func,
  onCancel: PropTypes.func
};

export default AlertModal;
