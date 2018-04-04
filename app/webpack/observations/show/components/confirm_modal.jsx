import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Modal, Button } from "react-bootstrap";

class ConfirmModal extends Component {

  constructor( ) {
    super( );
    this.close = this.close.bind( this );
    this.confirm = this.confirm.bind( this );
  }

  close( ) {
    this.props.setConfirmModalState( { show: false } );
  }

  confirm( ) {
    if ( _.isFunction( this.props.onConfirm ) ) {
      const inputs = { };
      _.each( $( ".ConfirmModal input" ), i => {
        const el = $( i );
        if ( el.is( "[type=checkbox]" ) ) {
          inputs[el.attr( "name" )] = el.is( ":checked" );
        } else {
          inputs[el.attr( "name" )] = el.val( );
        }
      } );
      this.props.onConfirm( inputs );
    }
    this.close( );
  }

  render( ) {
    let cancel;
    let message;
    if ( !this.props.hideCancel ) {
      cancel = (
        <Button bsStyle="default" onClick={ this.close }>
          { this.props.cancelText || I18n.t( "cancel" ) }
        </Button>
      );
    }
    if ( this.props.type === "coarserID" && this.props.idTaxon && this.props.existingTaxon ) {
      const idName = this.props.idTaxon.preferred_common_name || this.props.idTaxon.name;
      const existingName = this.props.existingTaxon.preferred_common_name ||
        this.props.existingTaxon.name;
      message = ( <span className="coarse_ids">
        Your coarser ID of <span className="taxon">{ idName }</span> implies that
        you disagree with the existing finer ID of <span className="taxon">
        { existingName }</span>. Is this what you want to do?
        <a href="/pages/getting+started" target="_blank" className="learn">
          Learn more about how identifications work »
        </a>
        <input type="checkbox" id="silenceCoarse" name="silenceCoarse" />
        <label htmlFor="silenceCoarse">Do not show this message again</label>
      </span> );
    }
    if ( this.props.type === "error" ) {
      let errorList;
      if ( this.props.errors ) {
        errorList = ( <ul>
          { _.map( this.props.errors, ( e, i ) => (
            <li key={ `error-${i}` }>{ e }</li>
          ) ) }
        </ul> );
      }
      message = ( <span>
        { this.props.message }
        { errorList }
      </span> );
    }
    return (
      <Modal
        show={ this.props.show }
        className={ `ConfirmModal confirm ${this.props.type}` }
        onHide={ this.close }
      >
        <Modal.Body>
          <div className="text">
            { message || this.props.message }
          </div>
        </Modal.Body>
        { !this.props.hideFooter && (
          <Modal.Footer>
           <div className="buttons">
              { cancel }
              <Button bsStyle={ this.props.confirmClass || "primary" } onClick={ this.confirm }>
                { this.props.confirmText || I18n.t( "confirm" ) }
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
  message: PropTypes.string,
  idTaxon: PropTypes.object,
  errors: PropTypes.array,
  existingTaxon: PropTypes.object,
  type: PropTypes.string,
  onConfirm: PropTypes.func,
  cancelText: PropTypes.string,
  confirmText: PropTypes.string,
  setConfirmModalState: PropTypes.func,
  hideCancel: PropTypes.bool,
  hideFooter: PropTypes.bool
};

export default ConfirmModal;
