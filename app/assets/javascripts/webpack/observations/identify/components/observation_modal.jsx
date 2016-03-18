import React, { PropTypes } from "react";
import { Modal, Row, Col } from "react-bootstrap";
import CommentFormContainer from "../containers/comment_form_container";

const ObservationModal = ( {
  onClose,
  observation,
  visible
} ) => (
  <Modal show={visible} onHide={onClose} bsSize="large">
    <Modal.Header closeButton>
      { /*
        So this whole optional observation business: the modal is always
        rendered, but the observation in the store is not
        always there, e.g. on first page load. I haven't figured out how to
        make something like this just render when it needs to be rendered and
        not before.
      */ }
      <Modal.Title>{observation ? observation.species_guess : ""}</Modal.Title>
    </Modal.Header>
    <Modal.Body>
      <Row>
        <Col xs={6}>
          <a href={ `/observations/${observation ? observation.id : ""}` }>
            <img
              src={observation ? observation.photo( ) : ""}
              style={ { width: "100%" } }
            />
          </a>
        </Col>
        <Col xs={6}>
          <CommentFormContainer observation={observation} />
        </Col>
      </Row>
    </Modal.Body>
  </Modal>
);

ObservationModal.propTypes = {
  onClose: PropTypes.func.isRequired,
  observation: PropTypes.object,
  visible: PropTypes.bool.isRequired
};

export default ObservationModal;
