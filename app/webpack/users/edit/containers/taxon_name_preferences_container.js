import { connect } from "react-redux";
import TaxonNamePreferences from "../components/taxon_name_preferences";

import {
  addTaxonNamePreference,
  deleteTaxonNamePreference
} from "../ducks/taxon_name_preferences";

function mapStateToProps( state ) {
  return {
    config: state.config,
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addTaxonNamePreference: ( lexicon, placeID ) => dispatch(
      addTaxonNamePreference( lexicon, placeID )
    ),
    deleteTaxonNamePreference: id => dispatch( deleteTaxonNamePreference( id ) )
  };
}

const TaxonNamePreferencesContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonNamePreferences );

export default TaxonNamePreferencesContainer;
