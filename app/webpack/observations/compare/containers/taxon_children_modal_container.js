import { connect } from "react-redux";
import { hideModal } from "../ducks/taxon_children_modal";
import { loadChildQueriesForTaxon } from "../ducks/compare";
import TaxonChildrenModal from "../components/taxon_children_modal";

function mapStateToProps( state ) {
  return {
    visible: state.taxonChildrenModal.visible
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    hideModal: ( ) => dispatch( hideModal( ) ),
    chooseTaxon: taxon => dispatch( loadChildQueriesForTaxon( taxon ) )
  };
}

const TaxonChildrenModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonChildrenModal );

export default TaxonChildrenModalContainer;
