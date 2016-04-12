import React, { PropTypes, Component } from "react";
import { Modal, Button } from "react-bootstrap";

class RemoveModal extends Component {

  constructor( props, context ) {
    super( props, context );
    this.close = this.close.bind( this );
    this.remove = this.remove.bind( this );
  }

  close( ) {
    this.props.setState( { removeModal: { open: false, count: this.props.count } } );
  }

  remove( ) {
    if ( this.props.count === 1 && this.props.obsCard ) {
      this.props.removeObsCard( this.props.obsCard );
    } else if ( this.props.count > 1 ) {
      this.props.removeSelected( );
    }
    this.close( );
  }

  render( ) {
    const { show } = this.props;
    let modalMessage;
    if ( this.props.count > 1 ) {
      modalMessage = `Remove ${this.props.count} observations?`;
    } else {
      modalMessage = "Remove 1 observation?";
    }
    return (
      <Modal show={ show } className="remove">
        <Modal.Body>
          <div className="text">
            { modalMessage }
          </div>
          <div className="buttons">
            <Button bsStyle="danger" onClick={this.remove}>Remove</Button>
            <Button bsStyle="default" onClick={this.close}>Cancel</Button>
          </div>
        </Modal.Body>
      </Modal>
    );
  }
}

RemoveModal.propTypes = {
  show: PropTypes.bool,
  count: PropTypes.number,
  obsCard: PropTypes.object,
  onConfirm: PropTypes.func,
  setState: PropTypes.func,
  removeObsCard: PropTypes.func,
  removeSelected: PropTypes.func
};

export default RemoveModal;
