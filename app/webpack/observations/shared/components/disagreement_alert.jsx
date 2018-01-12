import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import ReactDOMServer from "react-dom/server";
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
      newTaxon,
      oldTaxon,
      backdrop
    } = this.props;
    const newTaxonHTML = ReactDOMServer.renderToString( <SplitTaxon taxon={newTaxon} forceRank /> );
    const oldTaxonHTML = ReactDOMServer.renderToString( <SplitTaxon taxon={oldTaxon} forceRank /> );
    return (
      <Modal
        show={visible}
        className="DisagreementAlert"
        backdrop={backdrop}
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
          <p
            dangerouslySetInnerHTML={ { __html: I18n.t( "is_the_evidence_provided_enough_to_confirm_this_is_taxon", { taxon: oldTaxonHTML } ) } }
          />
          <Button
            bsStyle="success"
            className="btn-block stacked"
            onClick={ ( ) => {
              onBestGuess( );
              onClose( );
            } }
            dangerouslySetInnerHTML={ { __html: I18n.t( "i_dont_know_but_i_am_sure_this_is_taxon", { taxon: newTaxonHTML } ) } }
          />
          <Button
            bsStyle="warning"
            className="btn-block"
            onClick={ ( ) => {
              onDisagree( );
              onClose( );
            } }
            dangerouslySetInnerHTML={ { __html: I18n.t( "no_but_it_is_a_member_of_taxon", { taxon: newTaxonHTML } ) } }
          />
        </Modal.Body>
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
  oldTaxon: PropTypes.object,
  backdrop: PropTypes.bool
};

DisagreementAlert.defaultProps = {
  onCancel: ( ) => ( true )
};

export default DisagreementAlert;
