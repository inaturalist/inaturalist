import React, { PropTypes, Component } from "react";
import { Modal } from "react-bootstrap";

class StatusModal extends Component {

  render( ) {
    const { saveCounts, total, show } = this.props;

    let modalMessage;
    const savingCount = ( saveCounts.saving + saveCounts.saved + saveCounts.failed );
    if ( ( saveCounts.pending + saveCounts.saving ) === 0 ) {
      modalMessage = I18n.t( "going_to_your_observations" );
    } else {
      modalMessage = I18n.t( "saving_num_of_count_observations",
        { num: savingCount, count: total } );
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
