import React, { Component } from "react";
import PropTypes from "prop-types";
import ConfirmModal from "./confirm_modal";

class RemoveModal extends Component {

  constructor( props, context ) {
    super( props, context );
    this.onConfirm = this.onConfirm.bind( this );
    this.onClose = this.onClose.bind( this );
  }

  onConfirm( ) {
    if ( this.props.count === 1 && this.props.obsCard ) {
      this.props.removeObsCard( this.props.obsCard );
    } else if ( this.props.count > 0 ) {
      this.props.removeSelected( );
    }
    this.props.updateState( { removeModal: { show: false } } );
  }

  onClose( ) {
    this.props.updateState( { removeModal: { show: false } } );
  }

  render( ) {
    let message = I18n.t( "remove_observations", { count: this.props.count || 1 } );
    return (
      <ConfirmModal
        message={ message }
        onConfirm={ this.onConfirm }
        onClose={ this.onClose }
        confirmClass="danger"
        confirmText={ I18n.t( "remove" ) }
        { ...this.props }
      />
    );
  }
}

RemoveModal.propTypes = {
  count: PropTypes.number,
  obsCard: PropTypes.object,
  removeObsCard: PropTypes.func,
  removeSelected: PropTypes.func,
  updateState: PropTypes.func
};

export default RemoveModal;
