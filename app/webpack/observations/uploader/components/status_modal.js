import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Modal, Button } from "react-bootstrap";
import util from "../models/util";

class StatusModal extends Component {

  render( ) {
    let modalMessage;
    const saveCounts = this.props.saveCounts;
    const savingCount = ( saveCounts.saving + saveCounts.saved + saveCounts.failed );
    const totalPhotos = _.size( this.props.files );
    const photoIndex = totalPhotos - util.countPending( this.props.files );
    let footer;
    if ( totalPhotos !== photoIndex ) {
      modalMessage = I18n.t( "uploading_num_of_count_photos",
        { num: photoIndex || 1, count: totalPhotos } );
      footer = (
        <Modal.Footer>
         <div className="buttons">
            <Button
              bsStyle={ "primary" }
              onClick={ () => this.props.setState( { saveStatus: null } ) }
            >
              { I18n.t( "keep_editing" ) }
            </Button>
          </div>
        </Modal.Footer>
      );
    } else if ( ( saveCounts.pending + saveCounts.saving ) === 0 && savingCount !== 0 ) {
      if ( saveCounts.failed > 0 ) {
        return null;
      }
      modalMessage = I18n.t( "going_to_your_observations" );
    } else {
      modalMessage = I18n.t( "saving_num_of_count_observations",
        { num: savingCount || 1, count: this.props.total } );
    }
    return (
      <Modal show={ this.props.show } className="confirm status">
        <Modal.Body>
          <h3>{ modalMessage }</h3>
        </Modal.Body>
        { footer }
      </Modal>
    );
  }
}

StatusModal.propTypes = {
  files: PropTypes.object,
  saveCounts: PropTypes.object,
  setState: PropTypes.func,
  total: PropTypes.number,
  show: PropTypes.bool
};

export default StatusModal;
