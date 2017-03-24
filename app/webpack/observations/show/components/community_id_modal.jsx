import React, { PropTypes, Component } from "react";
import { Modal, Button } from "react-bootstrap";

class CommunityIDModal extends Component {

  constructor( props, context ) {
    super( props, context );
    this.close = this.close.bind( this );
  }

  close( ) {
    this.props.setCommunityIDModalState( { show: false } );
  }

  render( ) {
    const { show } = this.props;
    return (
      <Modal
        show={ show }
        className="CommunityIDModal"
        onHide={ this.close }
      >
        <Modal.Body>
          Table showing community ID breakdown
        </Modal.Body>
        <Modal.Footer>
         <div className="buttons">
            <Button bsStyle="primary" onClick={ this.close }>
              OK
            </Button>
          </div>
        </Modal.Footer>
      </Modal>
    );
  }
}

CommunityIDModal.propTypes = {
  observation: PropTypes.object,
  setCommunityIDModalState: PropTypes.func,
  show: PropTypes.bool
};

export default CommunityIDModal;
