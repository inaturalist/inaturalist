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
      backdrop,
      config
    } = this.props;
    const newTaxonHTML = ReactDOMServer.renderToString(
      <SplitTaxon taxon={newTaxon} forceRank config={ config } />
    );
    const oldTaxonHTML = ReactDOMServer.renderToString(
      <SplitTaxon taxon={oldTaxon} forceRank config={ config } />
    );
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
          <p>
            <span
              dangerouslySetInnerHTML={ { __html: I18n.t( "do_you_think_this_could_be_html" ) } }
            ></span> <SplitTaxon taxon={oldTaxon} forceRank config={ config } />?
          </p>
          <Button
            bsStyle="success"
            className="btn-block stacked"
            onClick={ ( ) => {
              onBestGuess( );
              onClose( );
            } }
            dangerouslySetInnerHTML={ { __html: I18n.t( "i_dont_know_but_taxon_is_my_best_guess", { taxon: newTaxonHTML } ) } }
          />
          <Button
            bsStyle="warning"
            className="btn-block"
            onClick={ ( ) => {
              onDisagree( );
              onClose( );
            } }
            dangerouslySetInnerHTML={ { __html: I18n.t( "i_am_sure_this_is_not_taxon", { taxon: oldTaxonHTML } ) } }
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
  backdrop: PropTypes.bool,
  config: PropTypes.object
};

DisagreementAlert.defaultProps = {
  onCancel: ( ) => ( true ),
  config: {}
};

export default DisagreementAlert;
