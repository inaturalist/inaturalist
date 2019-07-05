import React from "react";
import PropTypes from "prop-types";
import ReactDOMServer from "react-dom/server";
import {
  Modal,
  Button
} from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";

const DisagreementAlert = ( {
  visible,
  onDisagree,
  onBestGuess,
  onClose,
  onCancel,
  newTaxon,
  oldTaxon,
  backdrop,
  config
} ) => {
  const newTaxonHTML = ReactDOMServer.renderToString(
    <SplitTaxon taxon={newTaxon} forceRank config={config} />
  );
  const oldTaxonHTML = ReactDOMServer.renderToString(
    <SplitTaxon taxon={oldTaxon} forceRank config={config} />
  );
  const testingDisagreementTypes = config && config.currentUser
    && config.currentUser.roles
    && config.currentUser.roles.indexOf( "admin" ) >= 0;
  let buttons;
  if ( testingDisagreementTypes ) {
    buttons = (
      <span>
        <Button
          bsStyle="warning"
          className="btn-block stacked"
          onClick={( ) => {
            onDisagree( "leaf" );
            onClose( );
          }}
          dangerouslySetInnerHTML={{
            __html: I18n.t( "explicit_disagreement.yes_im_certain_its_not_taxon", { old_taxon: oldTaxonHTML, new_taxon: newTaxonHTML } )
          }}
        />
        <Button
          bsStyle="warning"
          className="btn-block stacked"
          onClick={( ) => {
            onDisagree( "branch" );
            onClose( );
          }}
          dangerouslySetInnerHTML={{
            __html: I18n.t( "explicit_disagreement.yes_we_cant_be_certain_beyond_taxon", { taxon: newTaxonHTML } )
          }}
        />
        <Button
          bsStyle="success"
          className="btn-block"
          onClick={( ) => {
            onBestGuess( );
            onClose( );
          }}
        >
          { I18n.t( "explicit_disagreement.no_im_not_disagreeing" ) }
        </Button>
      </span>
    );
  } else {
    buttons = (
      <span>
        <Button
          bsStyle="success"
          className="btn-block stacked"
          onClick={( ) => {
            onBestGuess( );
            onClose( );
          }}
          dangerouslySetInnerHTML={{ __html: I18n.t( "i_dont_know_but_i_am_sure_this_is_taxon", { taxon: newTaxonHTML } ) }}
        />
        <Button
          bsStyle="warning"
          className="btn-block"
          onClick={( ) => {
            onDisagree( );
            onClose( );
          }}
          dangerouslySetInnerHTML={{ __html: I18n.t( "no_but_it_is_a_member_of_taxon", { taxon: newTaxonHTML } ) }}
        />
      </span>
    );
  }
  return (
    <Modal
      show={visible}
      className="DisagreementAlert"
      backdrop={backdrop}
      onHide={( ) => {
        onCancel( );
        onClose( );
      }}
    >
      <Modal.Header closeButton>
        <Modal.Title>
          { I18n.t( "potential_disagreement" ) }
        </Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <p
          dangerouslySetInnerHTML={{
            __html: I18n.t(
              "explicit_disagreement.are_you_disagreeing_this_is_taxon",
              { taxon: oldTaxonHTML }
            )
          }}
        />
        { buttons }
      </Modal.Body>
    </Modal>
  );
};

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
