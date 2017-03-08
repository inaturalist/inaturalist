import React, { Component, PropTypes } from "react";
import { Button, Modal } from "react-bootstrap";

class ErrorModal extends Component {

  constructor( ) {
    super( );
    this.close = this.close.bind( this );
  }

  close( ) {
    this.props.setErrorModalState( { show: false } );
  }

  render( ) {
    let errorList;
    if ( this.props.state.errors ) {
      errorList = ( <ul>
        { this.props.state.errors.map( e => (
          <li>{ e }</li>
        ) ) }
      </ul> );
    }
    return (
      <Modal
        show={ this.props.state.show }
        className="ErrorModal"
        backdrop="static"
        onHide={ this.close }
      >
        <Modal.Header closeButton>
          <Modal.Title>
            Error
          </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          { this.props.state.message }
          { errorList }
        </Modal.Body>
        <Modal.Footer>
          <Button onClick={ this.close }>
            { I18n.t( "ok" ) }
          </Button>
        </Modal.Footer>
      </Modal>
    );
  }
}

ErrorModal.propTypes = {
  config: PropTypes.object,
  state: PropTypes.object,
  setErrorModalState: PropTypes.func
};

export default ErrorModal;
