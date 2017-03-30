import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import {
  Modal,
  Button
} from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";

class DisagreementAlert extends React.Component {
  render( ) {
    const {
      visible,
      onDisagree,
      onBestGuess,
      onClose,
      onCancel,
      oldTaxon
    } = this.props;
    return (
      <Modal
        show={visible}
        className="DisagreementAlert"
        bsSize="small"
        backdrop={false}
        onHide={ ( ) => {
          onCancel( );
          onClose( );
        } }
        onEntered={ ( ) => {
          $( ReactDOM.findDOMNode( this.refs.cancel ) ).focus();
        } }
      >
        <Modal.Header closeButton>
          <Modal.Title>
            { I18n.t( "potential_disagreement" ) }
          </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <p>
            <span
              dangerouslySetInnerHTML={ { __html: I18n.t( "do_you_think_this_could_be_html" ) } }
            ></span> <SplitTaxon taxon={oldTaxon} forceRank />?
          </p>
        </Modal.Body>
        <Modal.Footer>
          <Button
            ref="cancel"
            autoFocus
            onClick={ ( ) => {
              onCancel( );
              onClose( );
            } }
          >
            { I18n.t( "cancel" ) }
          </Button>
          <Button
            bsStyle="danger"
            onClick={ ( ) => {
              onDisagree( );
              onClose( );
            } }
          >
            { I18n.t( "no" ) }
          </Button>
          <Button
            bsStyle="success"
            onClick={ ( ) => {
              onBestGuess( );
              onClose( );
            } }
          >
            { I18n.t( "yes" ) }
          </Button>
        </Modal.Footer>
      </Modal>
    );
  }
}

DisagreementAlert.propTypes = {
  visible: PropTypes.bool,
  onClose: PropTypes.func,
  onCancel: PropTypes.func,
  onDisagree: PropTypes.func,
  onBestGuess: PropTypes.func,
  newTaxon: PropTypes.object,
  oldTaxon: PropTypes.object
};

export default DisagreementAlert;
