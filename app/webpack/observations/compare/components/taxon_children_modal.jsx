import React from "react";
import PropTypes from "prop-types";
import { Modal } from "react-bootstrap";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";

class TaxonChildrenModal extends React.Component {
  constructor( ) {
    super( );
    this.state = { taxon: null };
  }

  render( ) {
    const { visible, hideModal, chooseTaxon } = this.props;
    return (
      <Modal
        show={visible}
        onHide={hideModal}
        className="FinishedModal"
      >
        <Modal.Header closeButton>
          <Modal.Title>
            Show Children of Taxon
          </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <p>
            Choose a taxon to show queries for all of its children (will remove
            all existing queries)
          </p>
          <TaxonAutocomplete
            afterSelect={result => this.setState( { taxon: result.item } )}
            afterUnelect={( ) => this.setState( { taxon: null } )}
          />
        </Modal.Body>
        <Modal.Footer>
          <button
            type="button"
            className="btn btn-primary"
            onClick={( ) => {
              if ( this.state.taxon ) {
                chooseTaxon( this.state.taxon );
              }
              hideModal( );
            }}
          >
            Show Children
          </button>
        </Modal.Footer>
      </Modal>
    );
  }
}

TaxonChildrenModal.propTypes = {
  visible: PropTypes.bool,
  hideModal: PropTypes.func,
  chooseTaxon: PropTypes.func
};

export default TaxonChildrenModal;
