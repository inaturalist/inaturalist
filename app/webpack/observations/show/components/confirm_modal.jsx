import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Modal, Button } from "react-bootstrap";

class ConfirmModal extends Component {
  constructor( ) {
    super( );
    this.cancel = this.cancel.bind( this );
    this.close = this.close.bind( this );
    this.confirm = this.confirm.bind( this );
  }

  close( ) {
    const { setConfirmModalState } = this.props;
    setConfirmModalState( { show: false } );
  }

  confirm( ) {
    const { onConfirm } = this.props;
    if ( _.isFunction( onConfirm ) ) {
      const inputs = { };
      _.each( $( ".ConfirmModal input" ), i => {
        const el = $( i );
        if ( el.is( "[type=checkbox]" ) ) {
          inputs[el.attr( "name" )] = el.is( ":checked" );
        } else {
          inputs[el.attr( "name" )] = el.val( );
        }
      } );
      onConfirm( inputs );
    }
    this.close( );
  }

  cancel( ) {
    const { onCancel } = this.props;
    if ( _.isFunction( onCancel ) ) {
      onCancel( );
    }
    this.close( );
  }

  render( ) {
    const {
      cancelText,
      confirmClass,
      confirmText,
      errors,
      hideCancel,
      hideFooter,
      message,
      show,
      type
    } = this.props;
    let cancel;
    let messageElt;
    if ( !hideCancel ) {
      cancel = (
        <Button bsStyle="default" onClick={this.cancel}>
          { cancelText || I18n.t( "cancel" ) }
        </Button>
      );
    }
    if ( type === "error" ) {
      let errorList;
      if ( errors ) {
        errorList = (
          <ul>
            { _.map( errors, ( e, i ) => (
              <li key={`error-${i}`}>{ e }</li>
            ) ) }
          </ul>
        );
      }
      messageElt = (
        <span>
          { message }
          { errorList }
        </span>
      );
    }
    return (
      <Modal
        show={show}
        className={`ConfirmModal confirm ${type}`}
        onHide={this.close}
      >
        <Modal.Body>
          <div className="text" dangerouslySetInnerHTML={{ __html: messageElt || message }} />
        </Modal.Body>
        { !hideFooter && (
          <Modal.Footer>
            <div className="buttons">
              { cancel }
              <Button
                bsStyle={confirmClass || "primary"}
                onClick={this.confirm}
              >
                { confirmText || I18n.t( "confirm" ) }
              </Button>
            </div>
          </Modal.Footer>
        ) }
      </Modal>
    );
  }
}

ConfirmModal.propTypes = {
  show: PropTypes.bool,
  confirmClass: PropTypes.string,
  message: PropTypes.any,
  errors: PropTypes.array,
  type: PropTypes.string,
  onCancel: PropTypes.func,
  onConfirm: PropTypes.func,
  cancelText: PropTypes.string,
  confirmText: PropTypes.string,
  setConfirmModalState: PropTypes.func,
  hideCancel: PropTypes.bool,
  hideFooter: PropTypes.bool
};

export default ConfirmModal;
