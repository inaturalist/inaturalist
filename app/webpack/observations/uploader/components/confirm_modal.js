import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Modal, Button } from "react-bootstrap";

class ConfirmModal extends Component {

  constructor( props, context ) {
    super( props, context );
    this.close = this.close.bind( this );
    this.confirm = this.confirm.bind( this );
  }

  close( ) {
    if ( _.isFunction( this.props.onClose ) ) {
      this.props.onClose( );
    }
    this.props.updateState( { confirmModal: { show: false } } );
  }

  confirm( ) {
    if ( _.isFunction( this.props.onConfirm ) ) {
      this.props.onConfirm( );
    }
    this.close( );
  }

  render( ) {
    const { show } = this.props;
    let cancel;
    if ( !this.props.hideCancel ) {
      cancel = (
        <Button bsStyle="default" onClick={ this.close }>
          { this.props.cancelText || I18n.t( "cancel" ) }
        </Button>
      );
    }
    return (
      <Modal show={ show } className="confirm" onHide={ this.close }>
        <Modal.Body>
          <div className="text">
            { this.props.message }
          </div>
        </Modal.Body>
        <Modal.Footer>
         <div className="buttons">
            { cancel }
            <Button bsStyle={ this.props.confirmClass || "primary" } onClick={ this.confirm }>
              { this.props.confirmText || I18n.t( "confirm" ) }
            </Button>
          </div>
        </Modal.Footer>
      </Modal>
    );
  }
}

ConfirmModal.propTypes = {
  show: PropTypes.bool,
  message: PropTypes.string,
  onClose: PropTypes.func,
  onConfirm: PropTypes.func,
  cancelText: PropTypes.string,
  confirmText: PropTypes.string,
  confirmClass: PropTypes.string,
  updateState: PropTypes.func,
  hideCancel: PropTypes.bool
};

export default ConfirmModal;
