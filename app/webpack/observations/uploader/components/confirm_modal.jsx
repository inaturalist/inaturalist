import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Modal, Button } from "react-bootstrap";

class ConfirmModal extends Component {
  constructor( props, context ) {
    super( props, context );
    this.cancel = this.cancel.bind( this );
    this.close = this.close.bind( this );
    this.confirm = this.confirm.bind( this );
  }

  close( ) {
    const { onClose, updateState } = this.props;
    if ( _.isFunction( onClose ) ) {
      onClose( );
    }
    updateState( { confirmModal: { show: false } } );
  }

  confirm( ) {
    const { onConfirm } = this.props;
    this.close( );
    if ( _.isFunction( onConfirm ) ) {
      onConfirm( );
    }
  }

  cancel( ) {
    const { onCancel } = this.props;
    this.close( );
    if ( _.isFunction( onCancel ) ) {
      onCancel( );
    }
  }

  render( ) {
    const {
      cancelText,
      confirmClass,
      confirmText,
      hideCancel,
      message,
      show,
      title
    } = this.props;
    let cancel;
    if ( !hideCancel ) {
      cancel = (
        <Button
          bsStyle="default"
          onClick={this.cancel}
        >
          { cancelText || I18n.t( "cancel" ) }
        </Button>
      );
    }
    return (
      <Modal show={show} className="confirm" onHide={this.close}>
        { title && (
          <Modal.Header>
            <h4>{ title }</h4>
          </Modal.Header>
        ) }
        <Modal.Body>
          <div className="text">
            { message }
          </div>
        </Modal.Body>
        <Modal.Footer>
          <div className="buttons">
            { cancel }
            <Button bsStyle={confirmClass || "primary"} onClick={this.confirm}>
              { confirmText || I18n.t( "confirm" ) }
            </Button>
          </div>
        </Modal.Footer>
      </Modal>
    );
  }
}

ConfirmModal.propTypes = {
  show: PropTypes.bool,
  message: PropTypes.any,
  onCancel: PropTypes.func,
  onClose: PropTypes.func,
  onConfirm: PropTypes.func,
  cancelText: PropTypes.string,
  confirmText: PropTypes.string,
  confirmClass: PropTypes.string,
  updateState: PropTypes.func,
  hideCancel: PropTypes.bool,
  title: PropTypes.string
};

export default ConfirmModal;
