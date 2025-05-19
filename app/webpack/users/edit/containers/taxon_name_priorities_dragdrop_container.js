import { connect } from "react-redux";
import TaxonNamePrioritiesDragDrop from "../components/taxon_name_priorities_dragdrop";

import {
  deleteTaxonNamePriority,
  updateTaxonNamePriority
} from "../ducks/taxon_name_priorities";

function mapStateToProps( state ) {
  return {
    config: state.config,
    taxonNamePriorities: state.userSettings.taxon_name_priorities
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    deleteTaxonNamePriority: id => dispatch( deleteTaxonNamePriority( id ) ),
    updateTaxonNamePriority: ( id, newPosition ) => dispatch(
      updateTaxonNamePriority( id, newPosition )
    )
  };
}

const TaxonNamePrioritiesDragdropContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonNamePrioritiesDragDrop );

export default TaxonNamePrioritiesDragdropContainer;
