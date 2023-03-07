import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import {
  Modal,
  Button
} from "react-bootstrap";

const AlertModal = ( {
  backdrop,
  confirmText,
  content,
  onCancel,
  onClose,
  onConfirm,
  title,
  visible
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
          { confirmText || I18n.t( "ok" ) }
        </Button>
      </Modal.Footer>
    );
  }
  return (
    <Modal
      show={visible}
      className="AlertModal"
      bsSize="small"
      backdrop={backdrop}
      onHide={onClose}
    >
      <Modal.Header closeButton>
        <Modal.Title>
          { title || I18n.t( "alert" ) }
        </Modal.Title>
      </Modal.Header>
      { _.isObject( content ) ? (
        <Modal.Body>
          { content }
        </Modal.Body>
      ) : (
        <Modal.Body dangerouslySetInnerHTML={{ __html: content }} />
      ) }
      { modalFooter }
    </Modal>
  );
};

AlertModal.propTypes = {
  visible: PropTypes.bool,
  title: PropTypes.string,
  content: PropTypes.any,
  confirmText: PropTypes.string,
  onConfirm: PropTypes.func,
  onClose: PropTypes.func,
  onCancel: PropTypes.func,
  backdrop: PropTypes.bool
};

export default AlertModal;
