import { connect } from "react-redux";
import { DragDropContext } from "react-dnd";
import HTML5Backend from "react-dnd-html5-backend";
import TaxonNamePreferencesDragDrop from "../components/taxon_name_preferences_dragdrop";

import {
  deleteTaxonNamePreference,
  updateTaxonNamePreference
} from "../ducks/taxon_name_preferences";

function mapStateToProps( state ) {
  return {
    config: state.config,
    taxonNamePreferences: state.profile.taxon_name_preferences
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    deleteTaxonNamePreference: id => dispatch( deleteTaxonNamePreference( id ) ),
    updateTaxonNamePreference: ( id, newPosition ) => dispatch(
      updateTaxonNamePreference( id, newPosition )
    )
  };
}

const TaxonNamePreferencesDragdropContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( DragDropContext( HTML5Backend )( TaxonNamePreferencesDragDrop ) );

export default TaxonNamePreferencesDragdropContainer;
