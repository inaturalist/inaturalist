import { connect } from "react-redux";
import { DragDropContext } from "react-dnd";
import HTML5Backend from "react-dnd-html5-backend";
import TaxonNamePrioritiesDragDrop from "../components/taxon_name_priorities_dragdrop";

import {
  deleteTaxonNamePriority,
  updateTaxonNamePriority
} from "../ducks/taxon_name_priorities";

function mapStateToProps( state ) {
  return {
    config: state.config,
    taxonNamePriorities: state.profile.taxon_name_priorities
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
)( DragDropContext( HTML5Backend )( TaxonNamePrioritiesDragDrop ) );

export default TaxonNamePrioritiesDragdropContainer;
