import { connect } from "react-redux";
import Sugggestions from "../components/suggestions";
import { setDetailTaxon, updateQuery, fetchSuggestions } from "../ducks/suggestions";

function mapStateToProps( state ) {
  return state.suggestions;
}

function mapDispatchToProps( dispatch ) {
  return {
    setDetailTaxon: taxon => dispatch( setDetailTaxon( taxon ) ),
    setQuery: query => {
      dispatch( updateQuery( query ) );
      dispatch( fetchSuggestions( ) );
    }
  };
}

const SuggestionsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Sugggestions );

export default SuggestionsContainer;
