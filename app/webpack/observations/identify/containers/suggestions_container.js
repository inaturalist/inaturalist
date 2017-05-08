import { connect } from "react-redux";
import Sugggestions from "../components/suggestions";
import { setDetailTaxon } from "../ducks/suggestions";

function mapStateToProps( state ) {
  return state.suggestions;
}

function mapDispatchToProps( dispatch ) {
  return {
    setDetailTaxon: taxon => dispatch( setDetailTaxon( taxon ) )
  };
}

const SuggestionsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Sugggestions );

export default SuggestionsContainer;
