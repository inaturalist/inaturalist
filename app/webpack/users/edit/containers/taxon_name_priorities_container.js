import { connect } from "react-redux";
import TaxonNamePriorities from "../components/taxon_name_priorities";

import {
  addTaxonNamePriority,
  deleteTaxonNamePriority
} from "../ducks/taxon_name_priorities";

function mapStateToProps( state ) {
  return {
    config: state.config,
    profile: state.profile,
    taxonNamePriorities: state.profile.taxon_name_priorities
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addTaxonNamePriority: ( lexicon, placeID ) => dispatch(
      addTaxonNamePriority( lexicon, placeID )
    ),
    deleteTaxonNamePriority: id => dispatch( deleteTaxonNamePriority( id ) )
  };
}

const TaxonNamePrioritiesContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonNamePriorities );

export default TaxonNamePrioritiesContainer;
