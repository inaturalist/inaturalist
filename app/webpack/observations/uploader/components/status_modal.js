import React, { PropTypes, Component } from "react";
import { Modal } from "react-bootstrap";

class StatusModal extends Component {

  render( ) {
    const { saveCounts, total, show } = this.props;

    let modalMessage;
    const savingCount = ( saveCounts.saving + saveCounts.saved + saveCounts.failed );
    if ( ( saveCounts.pending + saveCounts.saving ) === 0 ) {
      modalMessage = "Going to your observations...";
    } else {
      modalMessage = `Saving ${savingCount || 1} of ${total} observations...`;
    }
    return (
      <Modal show={ show } className="status">
        <Modal.Body>
          <h3>{ modalMessage }</h3>
        </Modal.Body>
      </Modal>
    );
  }
}

StatusModal.propTypes = {
  saveCounts: PropTypes.object,
  total: PropTypes.number,
  show: PropTypes.bool
};

export default StatusModal;
