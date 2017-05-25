import { connect } from "react-redux";
import Sugggestions from "../components/suggestions";
import { setDetailTaxon, updateQuery, fetchSuggestions } from "../ducks/suggestions";

function mapStateToProps( state ) {
  return Object.assign( {}, state.suggestions, {
    observation: Object.assign( {}, state.currentObservation.observation )
  } );
}

function mapDispatchToProps( dispatch ) {
  return {
    setDetailTaxon: ( taxon, options = {} ) => {
      dispatch( setDetailTaxon( taxon, options ) );
    },
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
