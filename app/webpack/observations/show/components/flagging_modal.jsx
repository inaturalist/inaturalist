import React, { PropTypes } from "react";
import { Button, Modal } from "react-bootstrap";


const FlaggingModal = ( { state, setState } ) => {
  return (
    <Modal
      show={ state.open }
      className="location"
      backdrop="static"
    >
      <Modal.Header closeButton>
        <Modal.Title>
          Flag
        </Modal.Title>
      </Modal.Header>
      <Modal.Body>
        Body
      </Modal.Body>
      <Modal.Footer>
        <Button>{ I18n.t( "cancel" ) }</Button>
        <Button>
          { I18n.t( "save" ) }
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

FlaggingModal.propTypes = {
  state: PropTypes.object,
  setState: PropTypes.func
};

export default FlaggingModal;
